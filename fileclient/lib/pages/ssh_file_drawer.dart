import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:animations/animations.dart';
import 'package:contextmenu/contextmenu.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fileclient/event.dart';
import 'package:fileclient/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;
import 'package:data_table_2/data_table_2.dart';
import 'package:toastification/toastification.dart';
import '../dialog/message_dialog.dart';
import '../global.dart';
import '../icons/filetype1.dart';
import '../icons/filetype2.dart';
import 'ssh/helper.dart';
import 'ssh_file_toolbar.dart';

class _SortIcon extends StatelessWidget {
  final bool ascending;
  final bool active;

  const _SortIcon({required this.ascending, required this.active});

  @override
  Widget build(BuildContext context) {
    return Icon(
      ascending ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
      size: 28,
      color: active ? Colors.cyan : null,
    );
  }
}

class SshFileDrawer extends StatefulWidget {
  const SshFileDrawer({required this.pageID, super.key});
  final int pageID;
  @override
  State<SshFileDrawer> createState() => _SshFileDrawerState();
}

class _SshFileDrawerState extends State<SshFileDrawer> {
  late StreamSubscription<EventXtermChanged> listenEventXtermChanged;
  late StreamSubscription<EventSshFileToolbar> listenEventSshFileToolbar;
  late StreamSubscription<EventWatchFileChanged> listenEventWatchFileChanged;

  final List<SftpName> _files = [];
  final TextStyle _textStyle = TextStyle(fontSize: 16);
  String _currPath = "";
  bool _showDotFile = false;
  bool _isTransing = false;
  double _transPercent = 0;

  final ReceivePort _receivePort = ReceivePort();
  Isolate? _isolate;

  void autoUploadFile(EventWatchFileChanged event) {
    Global.ssh[widget.pageID]?.sftp
        ?.open(event.remoteFilePath,
            mode: SftpFileOpenMode.create |
                SftpFileOpenMode.write |
                SftpFileOpenMode.truncate)
        .then((sftpFile) {
      var data = File(event.localFilePath).readAsBytesSync();
      sftpFile.writeBytes(data);
      sftpFile.close();
      toastification.show(
          title: Text("文件 ${path.basename(event.localFilePath)} 已上传"),
          autoCloseDuration: Duration(seconds: 3));
    });
  }

  Future<bool> onUpload() async {
    final FilePickerResult? file = await FilePicker.platform.pickFiles(
      dialogTitle: "选择要上传的文件",
      lockParentWindow: true,
    );
    if (file == null) {
      return false;
    }

    var remotePath =
        path.join(Global.ssh[widget.pageID]!.sftpPath, file.xFiles.first.name);
    _isolate = await Isolate.spawn(SftpHelper.uploadThread, [
      _receivePort.sendPort,
      remotePath,
      file.xFiles.first.path,
      Global.ssh[widget.pageID]?.sftpConfig
    ]);

    return true;
  }

  void onRecvTransMessage(dynamic message) {
    if (!mounted) {
      return;
    }
    switch (message[0]) {
      case "percent":
        setState(() {
          _isTransing = true;
          _transPercent = message[1];
        });
        break;
      case "upload_finish":
        toastification.show(
            title: Text("文件 ${baseName(message[1])} 已上传"),
            autoCloseDuration: Duration(seconds: 3));
        setState(() {
          _isTransing = false;
          _transPercent = 0;
          _isolate = null;
        });
        goto(_currPath);
        break;
      case "download_finish":
        toastification.show(
            title: Text("文件 ${baseName(message[1])} 已下载"),
            autoCloseDuration: Duration(seconds: 3));
        setState(() {
          _isTransing = false;
          _transPercent = 0;
          _isolate = null;
        });
        break;
    }
  }

  Future<bool> onDownload() async {
    if (_selectedFile == null) {
      toastification.show(
          title: Text("请先选择一个文件"), autoCloseDuration: Duration(seconds: 3));
      return false;
    }
    if (_selectedFile!.attr.type != SftpFileType.regularFile) {
      toastification.show(
          title: Text("不支持下载文件夹"), autoCloseDuration: Duration(seconds: 3));
      return false;
    }
    // NOTE:当前仅仅支持一个文件下载
    if (_isolate != null) {
      toastification.show(
          title: Text("正在传输中，请稍后再试"), autoCloseDuration: Duration(seconds: 3));
      return false;
    }
    final String? file = await FilePicker.platform.saveFile(
      fileName: _selectedFile!.filename,
      lockParentWindow: true,
    );
    if (file == null) {
      return false;
    }
    int totalSize = _selectedFile!.attr.size ?? 0;
    var remotePath = path.join(_currPath, _selectedFile!.filename);
    _isolate = await Isolate.spawn(SftpHelper.downloadThread, [
      _receivePort.sendPort,
      remotePath,
      file,
      totalSize,
      Global.ssh[widget.pageID]?.sftpConfig
    ]);

    return true;
  }

  void onToolbarAction(String action) {
    if (action == "upward") {
      goto(path.dirname(_currPath));
    } else if (action == "refresh") {
      goto(_currPath);
    } else if (action == "upload") {
      // 上传
      onUpload();
    } else if (action == "download") {
      // 下载
      if (_selectedFile == null) {
        return;
      }
      onDownload();
    } else if (action == "delete") {
      if (_selectedFile == null) {
        return;
      }
      Global.ssh[widget.pageID]?.sftp
          ?.remove(path.join(_currPath, _selectedFile?.filename))
          .then((_) => goto(_currPath));
    }
  }

  @override
  void initState() {
    super.initState();
    _currPath = Global.ssh[widget.pageID]?.sftpPath ?? "/";
    listenEventSshFileToolbar =
        EventBusSingleton.instance.on<EventSshFileToolbar>().listen((event) {
      if (event.pageID != widget.pageID) {
        return;
      }
      onToolbarAction(event.name);
    });
    listenEventXtermChanged =
        EventBusSingleton.instance.on<EventXtermChanged>().listen((event) {
      if (event.pageID != widget.pageID) {
        return;
      }
      if (event.action == XtermAction.changedPath) {
        goto(event.value);
      }
    });

    listenEventWatchFileChanged =
        EventBusSingleton.instance.on<EventWatchFileChanged>().listen((event) {
      if (event.fileType != "ssh") {
        return;
      }
      if (!mounted) {
        return;
      }
      if (event.type == WatchEventType.modified) {
        if (Global.userInfo.autoUploadFile == AutoUploadFile.always) {
          autoUploadFile(event);
          return;
        }
        showMessageDialog(context, "提示",
                "文件 ${path.basename(event.localFilePath)} 已修改，是否上传？",
                okText: "上传", ok2Text: "始终自动上传")
            .then((result) {
          if (result == MessageDialogResult.cancel) {
            return;
          }
          if (result == MessageDialogResult.ok2) {
            Global.userInfo.changeUserSetting("auto_upload_file",
                AutoUploadFile.always.name, (a) {}, onFailed);
          }
          autoUploadFile(event);
        });
      }
    });

    Future.delayed(Duration(milliseconds: 500), () {
      goto(_currPath);
    });
    _receivePort.listen(onRecvTransMessage);
  }

  @override
  void dispose() {
    listenEventXtermChanged.cancel();
    listenEventWatchFileChanged.cancel();
    listenEventSshFileToolbar.cancel();
    _isolate?.kill();
    super.dispose();
  }

  void goto(String filePath) {
    if (!Global.ssh.containsKey(widget.pageID)) {
      return;
    }
    try {
      Global.ssh[widget.pageID]?.sftp?.listdir(filePath).then((files) {
        _currPath = filePath;
        _files.clear();
        for (var file in files) {
          if (!_showDotFile && file.filename.startsWith(".")) {
            continue;
          }
          if (file.filename == ".") {
            continue;
          }
          if (file.filename == "..") {
            _files.insert(0, file);
            continue;
          }
          if (file.attr.isDirectory) {
            _files.add(file);
          }
        }
        for (var file in files) {
          if (!_showDotFile && file.filename.startsWith(".")) {
            continue;
          }
          if (!file.attr.isDirectory) {
            _files.add(file);
          }
        }
        if (mounted) {
          setState(() {});
        }
      }).catchError((e) {
        print(e);
      });
    } catch (e) {
      print(e);
    }
  }

  IconData getIconByFileName(SftpName file) {
    if (file.attr.isDirectory) {
      return FileType1.folder;
    }
    String extName = path.extension(file.filename);
    IconData? icon;
    extName = extName.toLowerCase().replaceFirst(".", "");
    for (var iconItem in FileType1Preview.iconList) {
      if (iconItem.propName == extName) {
        icon = iconItem.icon;
        break;
      }
    }
    if (icon == null) {
      for (var iconItem in FileType2Preview.iconList) {
        if (iconItem.propName == extName) {
          icon = iconItem.icon;
          break;
        }
      }
    }
    icon ??= FileType1.file;
    return icon;
  }

  SftpName? _selectedFile;

  void onSelect(SftpName file) {
    _selectedFile = file;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> onDoubleTap(SftpName file) async {
    if (file.attr.isDirectory) {
      goto(joinPath([_currPath, file.filename]));
    } else {
      if (file.attr.size == null) {
        return;
      }
      if (file.attr.size! > 1024 * 1024 * 10) {
        if (!mounted) {
          return;
        }
        MessageDialogResult? result = await showMessageDialog(
            context, "提示", "文件较大(${formatBytes(file.attr.size!, 2)}), 是否打开？",
            okText: "打开");
        if (result != MessageDialogResult.ok) {
          return;
        }
      }
      // 打开文件
      String remoteFilePath = joinPath([_currPath, file.filename]);
      Global.ssh[widget.pageID]?.sftp
          ?.open(remoteFilePath, mode: SftpFileOpenMode.read)
          .then((sftpFile) async {
        var data = await sftpFile.readBytes();
        sftpFile.close();

        String localFilePath = path.join(Global.cachePath, file.filename);
        Global.watcher.unwatch(localFilePath);
        File localFile = File(localFilePath);
        localFile.writeAsBytesSync(data);

        if (path.extension(localFilePath) == ".apk") {
          if (!await Global.requestInstallPermission()) {
            return;
          }
        }
        var result = await OpenFile.open(localFilePath);
        Global.logger?.i("open $localFilePath result: $result");

        Global.watcher
            .watch(widget.pageID, localFilePath, remoteFilePath, "ssh");
      });
    }
  }

  void showContextMenu(
    Offset offset,
    file,
  ) {
    onSelect(file);
    double maxWidth = 0;
    for (Map item in getSshFileToolbarItems(widget.pageID)) {
      if (item["icon"] == null) {
        continue;
      }
      final textPainter = TextPainter(
        text: TextSpan(text: item["name"], style: _textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(); // 计算文本的布局
      final width = textPainter.width; // 获取文本宽度
      maxWidth = maxWidth > width ? maxWidth : width;
    }
    showModal(
      context: context,
      configuration: FadeScaleTransitionConfiguration(
        barrierColor: Colors.transparent,
      ),
      builder: (context) => ContextMenu(
          position: offset,
          builder: (context) {
            List<Widget> popupMenuEntries = [];
            for (Map item in getSshFileToolbarItems(widget.pageID)) {
              if (item["icon"] == null) {
                popupMenuEntries.add(const Divider());
                continue;
              }
              popupMenuEntries.add(ListTile(
                leading: Icon(
                  item["icon"],
                  size: 24,
                ),
                title: Text(item["name"], style: _textStyle),
                onTap: () {
                  Navigator.of(context).pop();
                  item["onPressed"]();
                },
              ));
            }
            return popupMenuEntries;
          },
          verticalPadding: 4,
          width: maxWidth + 96),
    );
  }

  DataCell buildCell({required List<Widget> children, required SftpName file}) {
    return DataCell(
      GestureDetector(
        onDoubleTap: () => onDoubleTap(file),
        onSecondaryTapDown: (details) =>
            showContextMenu(details.globalPosition, file),
        onLongPressStart: (details) =>
            showContextMenu(details.globalPosition, file),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: children),
      ),
    );
  }

  List<DataRow> getItems() {
    List<DataRow> items = [];
    for (var file in _files) {
      DateTime dtModify = DateTime.fromMillisecondsSinceEpoch(
          (file.attr.modifyTime ?? 0) * 1000);
      DataRow item = DataRow(
        onSelectChanged: (select) => onSelect(file),
        color: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return Colors.blue[100]!;
          }
          if (_selectedFile == file) {
            return Colors.blue[300]!;
          }
          return Colors.transparent;
        }),
        cells: [
          buildCell(
            file: file,
            children: [
              Icon(getIconByFileName(file)),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  file.filename,
                  style: _textStyle,
                ),
              ),
            ],
          ),
          buildCell(
            file: file,
            children: [Expanded(child: Text(humanizerDatetime(dtModify)))],
          ),
          buildCell(
            file: file,
            children: [
              Expanded(
                  child: Text(file.attr.isFile
                      ? formatBytes(file.attr.size ?? 0, 2)
                      : ""))
            ],
          )
        ],
      );
      items.add(item);
    }
    return items;
  }

  double getDateWidth() {
    double maxWidth = 0;
    for (var file in _files) {
      DateTime dtModify = DateTime.fromMillisecondsSinceEpoch(
          (file.attr.modifyTime ?? 0) * 1000);
      final textPainter = TextPainter(
        text: TextSpan(text: humanizerDatetime(dtModify), style: _textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(); // 计算文本的布局
      final width = textPainter.width; // 获取文本宽度
      maxWidth = maxWidth > width ? maxWidth : width;
    }
    return maxWidth;
  }

  double getSizeWidth() {
    double maxWidth = 0;
    for (var file in _files) {
      final textPainter = TextPainter(
        text:
            TextSpan(text: formatBytes(file.attr.size!, 2), style: _textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(); // 计算文本的布局
      final width = textPainter.width; // 获取文本宽度
      maxWidth = maxWidth > width ? maxWidth : width;
    }
    return maxWidth;
  }

  bool _sortAscending = true;
  int? _sortColumnIndex;
  void onSort(int columnIndex, bool ascending) {
    _sortColumnIndex = columnIndex;
    _sortAscending = ascending;
    _files.sort((a, b) {
      switch (columnIndex) {
        case 0:
          return ascending
              ? a.filename.compareTo(b.filename)
              : b.filename.compareTo(a.filename);
        case 1:
          return ascending
              ? (a.attr.modifyTime ?? 0).compareTo(b.attr.modifyTime ?? 0)
              : (b.attr.modifyTime ?? 0).compareTo(a.attr.modifyTime ?? 0);
        case 2:
          int? asize = a.attr.isDirectory ? -1 : a.attr.size;
          int? bsize = b.attr.isDirectory ? -1 : b.attr.size;
          return ascending
              ? (asize ?? 0).compareTo(bsize ?? 0)
              : (bsize ?? 0).compareTo(asize ?? 0);
        default:
          return 0;
      }
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Padding(
        padding: EdgeInsets.only(left: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            !kIsWeb && Platform.isAndroid ? SizedBox(height: 24) : SizedBox(),
            SshFileToolbar(
              title: "文件列表",
              pageID: widget.pageID,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                      decoration: InputDecoration(hintText: "路径"),
                      controller: TextEditingController(text: _currPath),
                      onSubmitted: (value) {
                        goto(value);
                      }),
                ),
              ],
            ),
            Expanded(
              child: DataTable2(
                  columnSpacing: 12,
                  horizontalMargin: 12,
                  minWidth: 360,
                  headingRowHeight: 24,
                  showHeadingCheckBox: false,
                  showCheckboxColumn: false,
                  showBottomBorder: true,
                  sortColumnIndex: _sortColumnIndex,
                  sortAscending: _sortAscending,
                  sortArrowBuilder: (ascending, sorted) => sorted
                      ? Stack(
                          children: [
                            Padding(
                                padding: const EdgeInsets.only(right: 0),
                                child: _SortIcon(
                                    ascending: true,
                                    active: sorted && ascending)),
                            Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: _SortIcon(
                                    ascending: false,
                                    active: sorted && !ascending)),
                          ],
                        )
                      : null,
                  columns: [
                    DataColumn2(
                      label: Text("名称"),
                      headingRowAlignment: MainAxisAlignment.start,
                      onSort: onSort,
                    ),
                    DataColumn2(
                      label: Text("修改时间"),
                      headingRowAlignment: MainAxisAlignment.start,
                      fixedWidth: getDateWidth(),
                      onSort: onSort,
                    ),
                    DataColumn2(
                      label: Text("大小"),
                      headingRowAlignment: MainAxisAlignment.start,
                      fixedWidth: getSizeWidth(),
                      onSort: onSort,
                    ),
                  ],
                  rows: getItems()),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text("${_files.length}项"),
              Spacer(),
              IconButton(
                tooltip: "显示隐藏文件",
                splashRadius: 16,
                onPressed: () {
                  _showDotFile = !_showDotFile;
                  goto(_currPath);
                },
                icon: Icon(
                    _showDotFile ? Icons.visibility : Icons.visibility_off),
              ),
            ]),
            Visibility(
                visible: _isTransing,
                child: SizedBox(
                    height: 8,
                    child: LinearProgressIndicator(
                      value: _transPercent,
                      backgroundColor: Colors.grey,
                      valueColor:
                          const AlwaysStoppedAnimation(Colors.orangeAccent),
                      minHeight: 2,
                    )))
          ],
        ),
      ),
    );
  }
}
