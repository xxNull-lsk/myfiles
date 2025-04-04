import 'package:fileclient/backend/backend.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import '../event.dart';
import '../global.dart';
import '../util.dart';

enum PackageDialogResult {
  ok,
  cancel,
}

class PackageDialog extends StatefulWidget {
  final String title;
  final String content;
  final String cancelText;
  final String remoteFilePath;
  final String localFilePath;
  final String fileType;
  const PackageDialog({
    super.key,
    required this.title,
    required this.content,
    required this.cancelText,
    required this.remoteFilePath,
    required this.localFilePath,
    required this.fileType,
  });

  @override
  PackageDialogState createState() => PackageDialogState();
}

class PackageDialogState extends State<PackageDialog> {
  PackageInformation? _packageInfo;
  TransInfo? _downloadInfo;

  @override
  void initState() {
    Global.logger
        ?.i("package ${widget.remoteFilePath} to ${widget.localFilePath}...");
    start();

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> start() async {
    Backend.downloadPackage(
        widget.fileType, widget.remoteFilePath, widget.localFilePath,
        (bool isPacking, int count, int total,
            PackageInformation? packageInfo) {
      if (isPacking) {
        _packageInfo = packageInfo;
      } else {
        _downloadInfo ??= TransInfo();
        _downloadInfo!.update(count, total);
      }
      setState(() {});
    }, (result) {
      if (result["code"] != 0) {
        Global.logger?.e(
            "package ${widget.remoteFilePath} to ${widget.localFilePath} failed!${result["code"]}: ${result["message"]}");
        toastification.show(
          title: const Text("下载失败"),
          description: Text("错误信息：${result["code"]}(${result["message"]})"),
          autoCloseDuration: const Duration(seconds: 3),
        );
      } else {
        Global.logger?.i(
            "package ${widget.remoteFilePath} to ${widget.localFilePath} succeed!");
        toastification.show(
          title: const Text("下载成功"),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
      Navigator.pop(context);
    }, onFailed);
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
          Text("打包进度："),
          ..._packageInfo?.getWidgets() ?? [Text("等待中...")],
          const SizedBox(height: 10),
          Text("下载进度："),
          ..._downloadInfo?.getWidgets() ?? [Text("等待中...")],
        ],
      ),
      actions: [
        TextButton(
          child: Text(widget.cancelText),
          onPressed: () {
            // 取消打包或者下载任务
            Navigator.of(context).pop(PackageDialogResult.cancel);
          },
        ),
      ],
    );
  }
}

Future<PackageDialogResult?> showPackageDialog(BuildContext context,
    {required String title,
    required String content,
    required String remoteFilePath,
    required String localFilePath,
    required String fileType}) {
  return showDialog<PackageDialogResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return PackageDialog(
        title: title,
        content: content,
        remoteFilePath: remoteFilePath,
        localFilePath: localFilePath,
        fileType: fileType,
        cancelText: "取消",
      );
    },
  );
}
