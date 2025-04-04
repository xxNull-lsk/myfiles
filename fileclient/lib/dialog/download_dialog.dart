import 'dart:io';
import 'dart:isolate';

import 'package:fileclient/backend/backend.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:toastification/toastification.dart';
import 'package:path/path.dart' as p;

import '../backend/task_manager.dart';
import '../event.dart';
import '../file_types.dart';
import '../global.dart';

enum DownloadDialogResult {
  ok,
  cancel,
}

class DownloadDialog extends StatefulWidget {
  final String title;
  final String content;
  final String cancelText;
  final String remoteFilePath;
  final String localFilePath;
  final FileEntry fileEntry;
  final bool openIt;
  const DownloadDialog({
    super.key,
    required this.title,
    required this.content,
    required this.cancelText,
    required this.remoteFilePath,
    required this.localFilePath,
    required this.fileEntry,
    required this.openIt,
  });

  @override
  DownloadDialogState createState() => DownloadDialogState();
}

class DownloadDialogState extends State<DownloadDialog> {
  TransInfo? _downloadInfo;
  ReceivePort receivePort = ReceivePort();
  Isolate? _isolate;

  @override
  void initState() {
    Global.logger
        ?.i("download ${widget.remoteFilePath} to ${widget.localFilePath}...");
    receivePort.listen(onRecvMessage);
    Future.delayed(Duration.zero, () {
      startDownload();
    });

    super.initState();
  }

  @override
  void dispose() {
    if (_downloadInfo != null && !_downloadInfo!.isFinished) {
      File(widget.localFilePath).deleteSync();
    }
    _isolate?.kill();
    super.dispose();
  }

  Future<void> startDownload() async {
    // 如果本地文件存在并且文件的大小和最后修改时间相同，直接通知下载完成
    if (File(widget.localFilePath).existsSync()) {
      int localSize = File(widget.localFilePath).lengthSync();
      if (localSize == widget.fileEntry.size) {
        DateTime lastModified = File(widget.localFilePath).lastModifiedSync();
        Duration diff =
            lastModified.difference(widget.fileEntry.modifiedAt);
        if (diff.inSeconds < 1) {
          onRecvMessage([
            TransStatus.succeed,
            {"code": 0, "message": "ok"}
          ]);
          return;
        }
      }
    }
    _isolate = await Isolate.spawn(downloadThread, [
      receivePort.sendPort,
      widget.remoteFilePath,
      widget.localFilePath,
      widget.fileEntry,
      Global.backendURL,
      Global.token,
      Global.sessionId,
    ]);
  }

  void onRecvMessage(dynamic message) {
    if (!mounted) {
      return;
    }
    switch (message[0]) {
      case TransStatus.running:
        setState(() {
          _downloadInfo ??= TransInfo();
          _downloadInfo!.update(message[1], message[2]);
        });
        break;
      case TransStatus.succeed:
        onDownloadSucceed(message[1]);
        break;
      case TransStatus.failed:
        String ex = message[1];
        String method = message[2];
        String url = message[3];
        toastification.show(
          title: const Text("下载失败"),
          description: Text("$method $url 错误信息：$ex"),
          autoCloseDuration: const Duration(seconds: 3),
        );
        Navigator.pop(context, DownloadDialogResult.cancel);
        break;
    }
  }

  Future<void> onDownloadSucceed(Map result) async {
    Global.logger?.i(
        "download ${widget.remoteFilePath} to ${widget.localFilePath} finish");
    if (result["code"] == 0) {
      Global.logger?.e(
          "download ${widget.remoteFilePath} to ${widget.localFilePath} succeed!");
      if (widget.openIt) {
        if (p.extension(widget.localFilePath) == ".apk") {
          if (!await Global.requestInstallPermission()) {
            return;
          }
        }
        var result = await OpenFile.open(widget.localFilePath);
        Global.logger?.i("open ${widget.localFilePath} result: $result");
      }
      if (mounted) {
        Navigator.pop(context, DownloadDialogResult.ok);
      }
    } else {
      Global.logger?.e(
          "download ${widget.remoteFilePath} to ${widget.localFilePath} failed!");
      toastification.show(
        title: const Text("下载失败"),
        description: Text("错误信息：${result["code"]}(${result["message"]})"),
        autoCloseDuration: const Duration(seconds: 3),
      );
      Navigator.pop(context, DownloadDialogResult.cancel);
    }
  }

  static Future<void> downloadThread(List message) async {
    SendPort sendPort = message[0];
    String remoteFilePath = message[1];
    String localFilePath = message[2];
    FileEntry fileEntry = message[3];
    Global.backendURL = message[4];
    Global.token = message[5];
    Global.sessionId = message[6];
    return Backend.downloadFile(remoteFilePath, localFilePath, (curr, total) {
      sendPort.send([TransStatus.running, curr, total]);
    }, (result) {
      // 修改文件的最后修改时间
      File(localFilePath).setLastModifiedSync(fileEntry.modifiedAt);
      sendPort.send([TransStatus.succeed, result]);
    }, (ex, method, url) {
      sendPort.send([TransStatus.failed, ex.toString(), method, url]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.content),
          const SizedBox(height: 10),
          _downloadInfo?.getPortraitWidget() ?? Container(),
        ],
      ),
      actions: [
        TextButton(
          child: Text(widget.cancelText),
          onPressed: () {
            _isolate?.kill();
            Navigator.of(context).pop(DownloadDialogResult.cancel);
          },
        ),
      ],
    );
  }
}

Future<DownloadDialogResult?> showDownloadDialog(BuildContext context,
    {required String title,
    required String content,
    required String remoteFilePath,
    required String localFilePath,
    required FileEntry fileEntry,
    required bool openIt}) async {
  return showDialog<DownloadDialogResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return DownloadDialog(
        title: title,
        content: content,
        fileEntry: fileEntry,
        remoteFilePath: remoteFilePath,
        localFilePath: localFilePath,
        openIt: openIt,
        cancelText: "取消",
      );
    },
  );
}
