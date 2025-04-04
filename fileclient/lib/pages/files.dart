import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:contextmenu/contextmenu.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fileclient/backend/backend.dart';
import 'package:fileclient/backend/task_manager.dart';
import 'package:fileclient/dialog/task_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toastification/toastification.dart';
import 'package:path/path.dart' as p;

import '../dialog/attributes_dialog.dart';
import '../dialog/create_shared_dialog.dart';
import '../dialog/download_dialog.dart';
import '../dialog/input_dialog.dart';
import '../dialog/message_dialog.dart';
import '../dialog/package_download.dart';
import '../event.dart';
import '../file_types.dart';
import '../global.dart';
import '../util.dart';
import 'base_page.dart';
import 'code_editor_page.dart';
import 'files_toolbar.dart';
import 'loading.dart';
import 'util/desktop_upload.dart' if (dart.library.html) 'util/web_upload.dart';

class FilesPage extends BasePage {
  const FilesPage({required this.pageID, super.key});

  final int pageID;

  @override
  IconData getIcon() {
    return Icons.folder;
  }

  @override
  String getTitle() {
    if (pageID == 0) {
      return baseName(Global.getPagePath(pageID));
    }
    return "${-pageID}.目录：${baseName(Global.getPagePath(pageID))}";
  }

  @override
  int getPageID() => pageID;

  @override
  PageType getPageType() => PageType.serverFiles;

  @override
  Widget getToolbar(bool isLandScape) {
    return FilesToolbar(
        pageID: pageID, isLandScape: isLandScape, key: GlobalKey());
  }

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  final String urlUpload = "/api/file/upload";
  bool _loading = false;
  List<String> _pathItems = [];
  final FileAttributes _fileAttributes = FileAttributes();
  String _currPath = "";
  late StreamSubscription<EventToolbar> listenEventToolbar;
  late StreamSubscription<EventGotoPath> listenEventGotoPath;
  late StreamSubscription<EventWatchFileChanged> listenEventWatchFileChanged;
  final ScrollController _pathItemController = ScrollController();
  @override
  void dispose() {
    super.dispose();
    //Global.pagePath.remove(widget.pageID);
    listenEventWatchFileChanged.cancel();
    listenEventToolbar.cancel();
    listenEventGotoPath.cancel();
    _pathItemController.dispose();
  }

  @override
  void didChangeDependencies() {
    ;
    super.didChangeDependencies();
    if (Global.filePages.containsKey(widget.pageID)) {
      String currPath = Global.getPagePath(widget.pageID);
      if (currPath != _currPath) {
        goto(currPath);
      }
    }
  }

  @override
  void didUpdateWidget(covariant FilesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  void _scrollToBottom(_) {
    if (!mounted) {
      return;
    }
    // 滚动到列表的最后
    _pathItemController.jumpTo(_pathItemController.position.maxScrollExtent);
  }

  void autoUploadFile(EventWatchFileChanged event) {
    if (event.pageID != widget.pageID) {
      return;
    }
    Backend.uploadFile(
        dirName(event.remoteFilePath), event.localFilePath, (a, b) {}, (res) {
      if (res["code"] != 0) {
        toastification.show(
          title: Text("自动上传${p.basename(event.localFilePath)}失败"),
          description: Text("${res["code"]}: ${res["message"]}"),
          type: ToastificationType.error,
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
      toastification.show(
        title: Text("自动上传${p.basename(event.localFilePath)}成功"),
        type: ToastificationType.success,
        autoCloseDuration: const Duration(seconds: 2),
      );
      if (dirName(event.remoteFilePath) == _currPath) {
        EventBusSingleton.instance
            .fire(EventGotoPath(widget.pageID, _currPath));
      }
    }, onFailed);
  }

  @override
  void initState() {
    super.initState();

    if (!Global.filePages.containsKey(widget.pageID)) {
      Global.filePages[widget.pageID] = PageData(_currPath, widget.pageID, 0);
    }
    WidgetsBinding.instance.addPostFrameCallback(_scrollToBottom);
    listenEventWatchFileChanged =
        EventBusSingleton.instance.on<EventWatchFileChanged>().listen((event) {
      if (!mounted) {
        return;
      }
      if (event.fileType != "fileserver") {
        return;
      }
      if (event.type == WatchEventType.modified) {
        if (Global.userInfo.autoUploadFile == AutoUploadFile.always) {
          autoUploadFile(event);
          return;
        }
        showMessageDialog(context, "提示",
                "文件 ${p.basename(event.localFilePath)} 已修改，是否上传？",
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
    listenEventGotoPath =
        EventBusSingleton.instance.on<EventGotoPath>().listen((event) {
      if (event.pageID != widget.pageID) {
        return;
      }
      if (event.path == "") {
        goto(Global.getPagePath(widget.pageID));
        return;
      }
      goto(event.path);
    });
    listenEventToolbar =
        EventBusSingleton.instance.on<EventToolbar>().listen((event) {
      if (event.pageID != widget.pageID) {
        return;
      }
      Global.logger?.d("file toolbar event: ${event.name}");
      switch (event.name) {
        case "refresh":
          EventBusSingleton.instance
              .fire(EventGotoPath(widget.pageID, _currPath));
          break;
        case "shared":
          onShared();
          break;
        case "rename":
          onRename();
          break;
        case "copy":
          onCopy();
          break;
        case "move":
          onMove();
          break;
        case "delete":
          onDelete();
          break;
        case "create_file":
          onNewFile();
          break;
        case "create_folder":
          onNewFolder();
          break;
        case "favorite":
          onFavorite();
          break;
        case "download":
          onDownload();
          break;
        case "download.zip":
          onDownloadPackage(".zip");
          break;
        case "download.tar.gz":
          onDownloadPackage(".tar.gz");
        case "upload":
          onUpload(widget.pageID, urlUpload, {"path": _currPath}, (a, b) {
            debugPrint("upload $a $b");
          }, (result) {
            setState(() {});
            getFileAttributes(_currPath);
          }, onFailed)
              .then((ret) {
            if (!kIsWeb && mounted && ret) {
              showTaskDialog(context);
            }
          });
          break;
        case "attribution":
          onAttribution();
          break;
        case "open_with":
          onOpenWith();
          break;
        case "sendto":
          onSendTo();
          break;
        case "sort_by_type":
          Global.filePages[widget.pageID]!.sortBy = SortBy.sortByType;
          onSort();
          break;
        case "sort_by_name":
          Global.filePages[widget.pageID]!.sortBy = SortBy.sortByName;
          onSort();
          break;
        case "sort_by_size":
          Global.filePages[widget.pageID]!.sortBy = SortBy.sortBySize;
          onSort();
          break;
        case "sort_by_modified":
          Global.filePages[widget.pageID]!.sortBy = SortBy.sortByModified;
          onSort();
          break;
      }
      setState(() {});
    });
  }

  Future<void> onSendTo() async {
    if (Global.filePages[widget.pageID]!.selectedCount != 1) {
      return;
    }
    FileEntry? selectedFile;
    for (var file in Global.filePages[widget.pageID]!.fileItems) {
      if (file.selected) {
        selectedFile = file.entry;
        break;
      }
    }
    if (selectedFile == null) {
      return;
    }
    if (selectedFile.isDir) {
      toastification.show(
        title: Text("无法发送文件夹"),
        description: Text("请选择文件"),
        type: ToastificationType.error,
        autoCloseDuration: const Duration(seconds: 2),
      );
      return;
    }
    String localFilePath = p.join(Global.cachePath, selectedFile.name);
    await createDirectory(p.dirname(localFilePath));

    Global.watcher.unwatch(localFilePath);
    if (!mounted) {
      return;
    }
    DownloadDialogResult? downloadResult = await showDownloadDialog(
      context,
      title: "正在下载...",
      content: selectedFile.name,
      remoteFilePath: joinPath([_currPath, selectedFile.name]),
      localFilePath: localFilePath,
      fileEntry: selectedFile,
      openIt: false,
    );
    if (downloadResult != DownloadDialogResult.ok) {
      return;
    }
    final result = await Share.shareXFiles([XFile(localFilePath)]);
    Global.logger?.i("send file to... remote_file: ${joinPath([
          _currPath,
          selectedFile.name
        ])} result:$result");
  }

  Future<void> onOpenWithInWeb(String remoteFilePath) async {
    Backend.getFileContent(remoteFilePath, (result) async {
      if (result["code"] != 0) {
        toastification.show(
          title: Text("打开文件失败"),
          description: Text("${result["code"]}: ${result["message"]}"),
          type: ToastificationType.error,
          autoCloseDuration: const Duration(seconds: 2),
        );
        return;
      }
      String fileContent = result["data"];
      final text = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CodeEditorPage(
            filePath: remoteFilePath,
            initialContent: fileContent,
          ),
        ),
      );
      if (text == null) {
        return;
      }
      Backend.writeFileAsync(remoteFilePath, 0, text);
    }, onFailed);
  }

  void onOpenWith() async {
    if (Global.filePages[widget.pageID]!.selectedCount != 1) {
      return;
    }

    FileEntry? selectedFile;
    for (var file in Global.filePages[widget.pageID]!.fileItems) {
      if (file.selected) {
        selectedFile = file.entry;
        break;
      }
    }
    if (selectedFile == null) {
      return;
    }
    if (selectedFile.isDir) {
      toastification.show(
        title: Text("无法打开文件夹"),
        description: Text("请选择文件"),
        type: ToastificationType.error,
        autoCloseDuration: const Duration(seconds: 2),
      );
      return;
    }
    final remoteFilePath = joinPath([_currPath, selectedFile.name]);
    if (kIsWeb) {
      onOpenWithInWeb(remoteFilePath);
      return;
    }
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('选择打开方式'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'text'),
              child: Row(
                children: [
                  const Icon(Icons.article, size: 32, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text('文本'),
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'image'),
              child: Row(
                children: [
                  const Icon(Icons.image, size: 32, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text('图片'),
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'video'),
              child: Row(
                children: [
                  const Icon(Icons.videocam, size: 32, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text('视频'),
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'audio'),
              child: Row(
                children: [
                  const Icon(Icons.audiotrack, size: 32, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text('音频'),
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'archive'),
              child: Row(
                children: [
                  const Icon(Icons.folder_zip, size: 32, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text('压缩包'),
                ],
              ),
            ),
          ],
        );
      },
    );
    if (result == null) {
      return;
    }
    String localFilePath = p.join(Global.cachePath, selectedFile.name);
    await createDirectory(p.dirname(localFilePath));

    Global.watcher.unwatch(localFilePath);
    if (!mounted) {
      return;
    }
    DownloadDialogResult? downloadResult = await showDownloadDialog(
      context,
      title: "正在下载...",
      content: selectedFile.name,
      remoteFilePath: remoteFilePath,
      localFilePath: localFilePath,
      fileEntry: selectedFile,
      openIt: false,
    );
    if (downloadResult != DownloadDialogResult.ok) {
      return;
    }

    Global.watcher
        .watch(widget.pageID, localFilePath, remoteFilePath, "fileserver");

    // 根据用户选择的方式处理文件
    if (result == 'text') {
      /* TODO: 打开文件
      if (Platform.isAndroid) {
        final uri = await FileProvider.platform.getUriForFile(localFilePath);
        AndroidIntent intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: localFilePath,
          type: 'text/plain',
          flags: [FLAG_GRANT_READ_URI_PERMISSION]
        );
        await intent.launch();
      }*/

      // 使用code_editor打开文件进行编辑
      String? fileContent = await File(localFilePath).readAsString();
      if (!mounted) {
        return;
      }
      fileContent = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CodeEditorPage(
            filePath: localFilePath,
            initialContent: fileContent!,
          ),
        ),
      );
      if (fileContent == null) {
        return;
      }
      File(localFilePath).writeAsString(fileContent);
    } else {
      final mimeType = {
        'image': 'image/png',
        'video': 'video/mp4',
        'audio': 'audio/mp3',
        'archive': 'application/zip',
      }[result];

      try {
        final openResult = await OpenFile.open(localFilePath, type: mimeType);
        if (openResult.type != ResultType.done) {
          throw Exception(openResult.message);
        }
      } catch (e) {
        toastification.show(
          title: Text("打开文件失败: ${e.toString()}"),
          type: ToastificationType.error,
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  void goto(String newPath) {
    getFileAttributes(newPath);
  }

  Future<void> createDirectory(String path) async {
    try {
      // 检查目录是否存在
      if (!await Directory(path).exists()) {
        // 如果不存在，则创建目录
        await Directory(path).create(recursive: true);
      }
    } catch (e) {
      Global.logger?.e(e);
    }
  }

  void onXtermSucceed(Map result, String xtermFilePath) {
    if (result["code"] != 0 || !result.containsKey("content")) {
      Global.logger?.e("打开终端失败!${result["code"]}: ${result["message"]}");
      toastification.show(
        title: const Text("打开终端失败"),
        description: Text("${result["code"]}: ${result["message"]}"),
        type: ToastificationType.error,
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
    // 读取文件内容
    try {
      String content = utf8.decode(base64Decode(result["content"]));
      Map<String, dynamic> cfg = jsonDecode(content);

      Global.filesKey.currentState
          ?.createXtermPage(XtermConfig(cfg), xtermFilePath);
    } catch (ex) {
      Global.logger?.e(ex);
      toastification.show(
        title: const Text("打开终端失败"),
        description: const Text("读取文件内容失败"),
        type: ToastificationType.error,
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> onOpen(FileEntry entry) async {
    if (p.extension(entry.name) == ".xterm" && entry.size < 102400) {
      bool openXtermAsTerminal =
          (Global.userInfo.openXtermAsTerminal == OpenXtermAsTerminal.always);
      if (Global.userInfo.openXtermAsTerminal == OpenXtermAsTerminal.ask) {
        MessageDialogResult? result =
            await showMessageDialog(context, "询问", "是否作为终端打开该文件？");
        if (result != null && result == MessageDialogResult.ok) {
          openXtermAsTerminal = true;
        }
      }
      if (openXtermAsTerminal) {
        // 读取文件内容
        String filePath = joinPath([_currPath, entry.name]);
        Backend.getFileContent(
            filePath, (result) => onXtermSucceed(result, filePath), onFailed);
        return;
      }
    }
    if (kIsWeb) {
      List fileItems = Global.filePages[widget.pageID]!.fileItems;
      for (int index = 0; index < fileItems.length; index++) {
        FileItem fileItem = fileItems[index];
        if (!fileItem.selected && fileItem.entry.name != entry.name) {
          continue;
        }

        onSelectFile(index);
        toastification.show(
          title: const Text("不支持在浏览器中打开文件"),
          description: const Text("请使用右上角工具栏中的下载功能下载后打开，或者使用客户端双击打开。"),
          autoCloseDuration: const Duration(seconds: 5),
        );
        return;
      }
    }
    if (entry.isDir) {
      return;
    }
    if (entry.size > 1024 * 1024 * 100) {
      if (!mounted) {
        return;
      }
      MessageDialogResult? result = await showMessageDialog(
          context, "提示", "文件较大(${formatBytes(entry.size, 2)}), 是否打开？",
          okText: "打开");
      if (result != MessageDialogResult.ok) {
        return;
      }
    }
    String localFilePath = p.join(Global.cachePath, entry.name);
    createDirectory(p.dirname(localFilePath)).then((value) async {
      if (!mounted) {
        return;
      }
      Global.watcher.unwatch(localFilePath);
      DownloadDialogResult? result = await showDownloadDialog(
        context,
        title: "正在下载...",
        content: entry.name,
        remoteFilePath: joinPath([_currPath, entry.name]),
        localFilePath: localFilePath,
        fileEntry: entry,
        openIt: true,
      );
      if (result == DownloadDialogResult.ok) {
        Global.watcher.watch(widget.pageID, localFilePath,
            joinPath([_currPath, entry.name]), "fileserver");
      }
    });
  }

  void onSort() {
    Global.filePages[widget.pageID]!.sortDesc =
        !Global.filePages[widget.pageID]!.sortDesc;
    Global.filePages[widget.pageID]!.fileItems.sort((a, b) {
      bool sortDesc = Global.filePages[widget.pageID]!.sortDesc;
      switch (Global.filePages[widget.pageID]!.sortBy) {
        case SortBy.sortByName:
          return sortDesc
              ? a.entry.name.compareTo(b.entry.name)
              : b.entry.name.compareTo(a.entry.name);
        case SortBy.sortBySize:
          int asize = a.entry.isDir ? -1 : a.entry.size;
          int bsize = b.entry.isDir ? -1 : b.entry.size;
          return sortDesc ? asize.compareTo(bsize) : bsize.compareTo(asize);
        case SortBy.sortByModified:
          return sortDesc
              ? a.entry.modifiedAt.compareTo(b.entry.modifiedAt)
              : b.entry.modifiedAt.compareTo(a.entry.modifiedAt);
        case SortBy.sortByCreated:
          return sortDesc
              ? a.entry.createdAt.compareTo(b.entry.createdAt)
              : b.entry.createdAt.compareTo(a.entry.createdAt);
        default:
          // 按类型排序
          if (a.entry.isDir == b.entry.isDir) {
            return 0;
          }
          if (a.entry.isDir) {
            return sortDesc ? -1 : 1;
          }
          if (b.entry.isDir) {
            return sortDesc ? 1 : -1;
          }
          return 0;
      }
    });
    setState(() {});
  }

  void onGetFolderSucceed(String newPath, Map result) {
    Global.filePages[widget.pageID]!.selectedCount = 0;
    Global.filePages[widget.pageID]!.fileItems.clear();
    EventBusSingleton.instance.fire(EventSelectFile(widget.pageID));
    for (var item in result["files"] ?? []) {
      FileItem fileItem = FileItem(fileEntry: item);
      if (fileItem.entry.isDir) {
        fileItem.onOpen = () {
          EventBusSingleton.instance.fire(EventGotoPath(
              widget.pageID, joinPath([_currPath, fileItem.entry.name])));
        };
      } else {
        fileItem.onOpen = () {
          onOpen(fileItem.entry);
        };
      }
      Global.filePages[widget.pageID]!.fileItems.add(fileItem);
    }
    onSort();
    String oldPath = _currPath;
    if (_pathItems.isNotEmpty && _pathItems.last.startsWith(_currPath)) {
      oldPath = _pathItems.last;
    }
    _currPath = newPath;
    Global.filePages[widget.pageID]?.path = _currPath;
    EventBusSingleton.instance.fire(EventUpdateTitle(widget.pageID));
    List<String> strPathItems = [];
    strPathItems.add(newPath);
    while (newPath != '/') {
      newPath = p.dirname(newPath);
      strPathItems.add(newPath);
    }
    if (oldPath.startsWith(_currPath)) {
      List<String> strExtPathItems = [];
      while (oldPath != _currPath) {
        strExtPathItems.add(oldPath);
        oldPath = p.dirname(oldPath);
      }
      strPathItems.insertAll(0, strExtPathItems);
    }
    _pathItems = strPathItems.reversed.toList();
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void getFileAttributesSuccess(String newPath, Map result) {
    if (!result["entry"]["is_dir"]) {
      setState(() {
        _loading = false;
      });
      toastification.show(title: const Text("不是目录，无法打开"));
      return;
    }
    _fileAttributes.fromJson(result);
    if (!_loading) {
      setState(() {
        _loading = true;
      });
    }
    Backend.getFolder(newPath, (result) {
      if (!mounted) {
        return;
      }
      onGetFolderSucceed(newPath, result);
      setState(() {
        _loading = false;
      });
    }, (a, b, c) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
      });
      onFailed(a, b, c);
    });
  }

  void getFileAttributes(String newPath) {
    if (newPath == "") {
      newPath = "/";
    }
    setState(() {
      _loading = true;
    });
    Backend.getFileAttribute(newPath, (result) {
      getFileAttributesSuccess(newPath, result);
    }, (a, b, c) {
      setState(() {
        _loading = false;
      });
      onFailed(a, b, c);
    });
  }

  void onShared() async {
    if (Global.filePages[widget.pageID]!.selectedCount == 0) {
      toastification.show(
        title: const Text("请选择要分享的文件或文件夹"),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return;
    }
    if (Global.filePages[widget.pageID]!.selectedCount > 1) {
      toastification.show(
        title: const Text("请选择单个文件或文件夹"),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return;
    }
    for (var file in Global.filePages[widget.pageID]!.fileItems) {
      if (!file.selected) {
        continue;
      }
      var sharedEntry = await showDialog<SharedEntry>(
        context: context,
        builder: (BuildContext context) {
          return CreateSharedDialog(name: file.entry.name);
        },
      );
      if (sharedEntry == null) {
        return;
      }
      String filePath = joinPath([_currPath, file.entry.name]);
      sharedEntry.path = filePath;
      Backend.createShared(sharedEntry, (result) {
        toastification.show(
          title: const Text("分享成功"),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }, onFailed);
    }
  }

  Future<void> onRename() async {
    for (var file in Global.filePages[widget.pageID]!.fileItems) {
      if (!file.selected) {
        continue;
      }
      String? newName = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return InputDialog(
            title: "新文件名",
            value: file.entry.name,
          );
        },
      );
      if (newName == null) {
        return;
      }
      String filePath = joinPath([_currPath, file.entry.name]);
      Backend.renameFile(filePath, newName, (result) {
        getFileAttributes(_currPath);
        toastification.show(
          title: const Text("改名成功"),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }, onFailed);
    }
  }

  void onCopy() {
    for (var file in Global.filePages[widget.pageID]!.fileItems) {
      if (!file.selected) {
        continue;
      }
      String filePath = joinPath([_currPath, file.entry.name]);
      EventBusSingleton.instance
          .fire(EventClipboard(widget.pageID, filePath, ClipboardAction.copy));
    }
  }

  void onMove() {
    for (var file in Global.filePages[widget.pageID]!.fileItems) {
      if (!file.selected) {
        continue;
      }
      String filePath = joinPath([_currPath, file.entry.name]);
      EventBusSingleton.instance
          .fire(EventClipboard(widget.pageID, filePath, ClipboardAction.cut));
    }
  }

  void onDelete() async {
    MessageDialogResult? result =
        await showMessageDialog(context, "提醒", "确定要删除选中的文件吗？");
    if (result == null || result != MessageDialogResult.ok) {
      return;
    }
    for (var file in Global.filePages[widget.pageID]!.fileItems) {
      if (!file.selected) {
        continue;
      }
      String filePath = joinPath([_currPath, file.entry.name]);
      Backend.deleteFile(filePath, (result) {
        toastification.show(
          title: Text("成功删除${file.entry.name}"),
          autoCloseDuration: const Duration(seconds: 3),
        );

        getFileAttributes(_currPath);
      }, onFailed);
    }
  }

  Future<void> onNewFile() async {
    String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return const InputDialog(
          title: "新文件名",
        );
      },
    );
    if (newName == null) {
      return;
    }
    Backend.createFile(_currPath, newName, (result) {
      getFileAttributes(_currPath);
      toastification.show(
        title: const Text("创建文件成功"),
        autoCloseDuration: const Duration(seconds: 3),
      );
    }, onFailed);
  }

  void onNewFolder() async {
    String? input = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return const InputDialog(
          title: "创建文件夹",
        );
      },
    );
    if (input == null) {
      return;
    }
    Backend.createFolder(joinPath([_currPath, input]), (result) {
      toastification.show(
        title: const Text("创建文件夹成功"),
        autoCloseDuration: const Duration(seconds: 3),
      );
      getFileAttributes(_currPath);
    }, onFailed);
  }

  Future<void> onFavorite() async {
    if (Global.filePages[widget.pageID]!.selectedCount > 0) {
      for (var file in Global.filePages[widget.pageID]!.fileItems) {
        if (!file.selected) {
          continue;
        }
        if (!file.entry.isDir) {
          toastification.show(
            title: const Text("只能收藏文件夹"),
            description: Text("文件${file.entry.name}已被忽略"),
            autoCloseDuration: const Duration(seconds: 3),
          );
          continue;
        }
        String? name = await showInputDialog(context,
            title: "请输入收藏夹名称", value: file.entry.name);
        if (name == null) {
          return;
        }
        Backend.createFavorites(name, joinPath([_currPath, file.entry.name]),
            (result) {
          EventBusSingleton.instance.fire(EventRefreshFavorites());
          toastification.show(
            title: const Text("收藏成功"),
            autoCloseDuration: const Duration(seconds: 3),
          );
        }, onFailed);
      }
    } else {
      String? name = await showInputDialog(context,
          title: "请输入收藏夹名称", value: baseName(_currPath));
      if (name == null) {
        return;
      }
      Backend.createFavorites(name, _currPath, (result) {
        EventBusSingleton.instance.fire(EventRefreshFavorites());
        toastification.show(
          title: const Text("收藏成功"),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }, onFailed);
    }
  }

  void downloadFile(FileItem file, String? locationPath) async {
    String localFilePath = file.entry.name;
    if (locationPath != null) {
      localFilePath = p.join(locationPath, localFilePath);
    }

    if (kIsWeb) {
      Backend.downloadFile(
          joinPath([_currPath, file.entry.name]), localFilePath,
          (int count, int total) {
        setState(() {});
      }, (result) {
        setState(() {});
        toastification.show(
          title: const Text("下载成功"),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }, onFailed);
      return;
    }

    bool addSucceed = Global.taskManager!.addTask(TransTaskItem(
      pageID: widget.pageID,
      taskType: TaskType.download,
      localFilePath: localFilePath,
      remoteFilePath: joinPath([_currPath, file.entry.name]),
    ));
    if (addSucceed == true) {
      showTaskDialog(context);
    }
  }

  void onDownload() async {
    bool ret = await Global.requestStoragePermission();
    if (!ret) {
      Global.logger?.w("没有存储权限");
      return;
    }
    ret = await Global.requestExternalStoragePermission();
    if (!ret) {
      Global.logger?.w("没有外部存储权限");
      return;
    }
    bool hasDir = false;
    String? locationPath;
    if (!kIsWeb) {
      locationPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: "选择下载目录",
        lockParentWindow: true,
      );
      if (locationPath == null) {
        return;
      }
    }
    for (var file in Global.filePages[widget.pageID]!.fileItems) {
      if (!file.selected) {
        continue;
      }
      if (file.entry.isDir) {
        hasDir = true;
        continue;
      }
      downloadFile(file, locationPath);
    }

    if (hasDir) {
      toastification.show(
        title: const Text("此方式不能下载文件夹，请使用下载为zip或tar.gz等压缩文件方式下载"),
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
  }

  void onDownloadPackage(String fileType) async {
    for (var file in Global.filePages[widget.pageID]!.fileItems) {
      if (!file.selected) {
        continue;
      }
      if (kIsWeb) {
        if (!mounted) {
          return;
        }
        showPackageDialog(context,
            title: "",
            content: "",
            remoteFilePath: joinPath([_currPath, file.entry.name]),
            localFilePath: file.entry.name,
            fileType: fileType);
        continue;
      }

      final String? location = await FilePicker.platform.getDirectoryPath(
        dialogTitle: "选择下载目录",
        lockParentWindow: true,
      );
      if (location == null) {
        return;
      }
      Global.taskManager?.addTask(
        TransTaskItem(
          pageID: widget.pageID,
          taskType: TaskType.package,
          localFilePath: p.join(location, file.entry.name + fileType),
          remoteFilePath: joinPath([_currPath, file.entry.name]),
          params: {
            "file_type": fileType,
          },
        ),
      );
      if (mounted) {
        showTaskDialog(context);
      }
    }
  }

  void onAttribution() async {
    FileAttributes fileAttributes = _fileAttributes;
    for (var file in Global.filePages[widget.pageID]!.fileItems) {
      if (file.selected) {
        fileAttributes.entry = file.entry;
        fileAttributes.fileCount = 0;
        fileAttributes.dirCount = 0;
        break;
      }
    }
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AttributesDialog(
          filePath: _currPath,
          attributes: fileAttributes,
        );
      },
    );
  }

  Future<void> onRefresh() async {
    setState(() {
      Global.filePages[widget.pageID]!.fileItems.clear();
      EventBusSingleton.instance.fire(EventSelectFile(widget.pageID));
      getFileAttributes(_currPath);
    });
  }

  void onSelectFile(int index, {bool onlySelect = false}) {
    if (onlySelect) {
      if (Global.filePages[widget.pageID]!.selectedCount > 1) {
        // 多选情况下，如果当前文件是选中状态，不需要做任何处理
        if (Global.filePages[widget.pageID]!.fileItems[index].selected) {
          return;
        }
      }
      for (var file in Global.filePages[widget.pageID]!.fileItems) {
        if (file.selected) {
          file.selected = false;
          Global.filePages[widget.pageID]!.selectedCount--;
        }
      }
    }
    setState(() {
      Global.filePages[widget.pageID]!.fileItems[index].selected =
          !Global.filePages[widget.pageID]!.fileItems[index].selected;
      if (Global.filePages[widget.pageID]!.fileItems[index].selected) {
        Global.filePages[widget.pageID]!.selectedCount++;
      } else {
        Global.filePages[widget.pageID]!.selectedCount--;
      }
      EventBusSingleton.instance.fire(EventSelectFile(widget.pageID));
    });
  }

  List<ListTile> onBuildContextMenu(BuildContext context) {
    List<ListTile> popupMenuEntries = [];
    for (Map item in getFileToolbarItems(widget.pageID)) {
      if (!isShow(
          item["show_mode"], Global.filePages[widget.pageID]!.selectedCount)) {
        continue;
      }
      popupMenuEntries.add(ListTile(
        leading: Icon(item["icon"]),
        title: Text(item["name"]),
        onTap: () {
          Navigator.of(context).pop();
          item["onPressed"]();
        },
      ));
    }
    return popupMenuEntries;
  }

  Widget? buildFiles(BuildContext context, int index) {
    List<FileItem> fileItems = Global.filePages[widget.pageID]!.fileItems;
    if (index >= fileItems.length) {
      return null;
    }
    var file = fileItems[index];
    List<Widget> subtitle = [
      Text(humanizerDatetime(file.entry.modifiedAt)),
    ];
    if (!file.entry.isDir) {
      subtitle.add(const Spacer());
      subtitle.add(Text(formatBytes(file.entry.size, 2)));
    }
    final double verticalPadding = 8, width = 320;
    return GestureDetector(
      onSecondaryTapDown: (details) {
        onSelectFile(index, onlySelect: true);
        showContextMenu(
          details.globalPosition,
          context,
          onBuildContextMenu,
          verticalPadding,
          width,
        );
      },
      onDoubleTap:
          Global.userInfo.openFileMode != OpenFileMode.doubleClickToOpen
              ? null
              : () {
                  fileItems[index].onOpen();
                },
      child: Container(
        color: fileItems[index].selected
            ? Theme.of(context).colorScheme.primary
            : Colors.transparent,
        child: ListTile(
          minTileHeight: 32,
          leading: Icon(
            fileItems[index].icon,
            size: 32,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(fileItems[index].entry.name),
          subtitle: Row(
            children: subtitle,
          ),
          selected: fileItems[index].selected,
          selectedColor: Theme.of(context).colorScheme.surface,
          onTap: () {
            // 如果有文件被选中，则进入多选模式
            if (Global.filePages[widget.pageID]!.selectedCount > 0) {
              onSelectFile(index);
              return;
            }
            if (Global.userInfo.openFileMode ==
                OpenFileMode.singleClickToOpen) {
              fileItems[index].onOpen();
            } else {
              onSelectFile(index);
            }
          },
          onLongPress:
              Global.userInfo.openFileMode != OpenFileMode.singleClickToOpen
                  ? null
                  : () {
                      // 如果是单选模式，则长按选中文件
                      onSelectFile(index);
                    },
        ),
      ),
    );
  }

  Widget? buildPathItem(BuildContext context, int index) {
    if (index >= _pathItems.length) {
      return null;
    }
    bool isCurrPath = _pathItems[index] == _currPath;
    if (isCurrPath) {
      Future.delayed(Duration(milliseconds: 100), () {
        if (!mounted) {
          return;
        }
        _pathItemController
            .jumpTo(_pathItemController.position.maxScrollExtent);
      });
    }
    if (index == 0) {
      return IconButton(
        padding: EdgeInsets.zero,
        splashRadius: 18,
        onPressed: isCurrPath
            ? null
            : () {
                EventBusSingleton.instance
                    .fire(EventGotoPath(widget.pageID, _pathItems[index]));
              },
        icon: Icon(Icons.home, color: isCurrPath ? Colors.grey : Colors.blue),
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chevron_right,
            color: Colors.grey,
          ),
          TextButton(
            style: ButtonStyle(
              padding: WidgetStateProperty.all(EdgeInsets.zero),
              minimumSize: WidgetStateProperty.all(const Size(0, 36)),
            ),
            onPressed: isCurrPath
                ? null
                : () => EventBusSingleton.instance
                    .fire(EventGotoPath(widget.pageID, _pathItems[index])),
            child: Text(baseName(_pathItems[index])),
          )
        ],
      );
    }
  }

  void onDragDone(DropDoneDetails detail) {
    if (widget.pageID != Global.currentPageID) {
      return;
    }
    if (kIsWeb) {
      toastification.show(
        title: const Text("web端不支持拖拽上传"),
        description: const Text("请使用右上角上传按钮上传或者客户端。"),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return;
    }
    for (var file in detail.files) {
      TransTaskItem task = TransTaskItem(
        pageID: widget.pageID,
        taskType: TaskType.upload,
        localFilePath: file.path,
        remoteFilePath: urlUpload,
        params: {"path": _currPath},
      );
      Global.taskManager!.addTask(task);
      showTaskDialog(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Colors.white,
        child: ProgressDialog(
          loading: _loading,
          child: RefreshIndicator(
            onRefresh: onRefresh, // 刷新回调函数
            child: ContextMenuArea(
              builder: onBuildContextMenu,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 32,
                    child: Padding(
                      padding: EdgeInsets.only(right: 16, left: 16),
                      child: Scrollbar(
                        controller: _pathItemController,
                        child: ListView.builder(
                            controller: _pathItemController,
                            scrollDirection: Axis.horizontal,
                            itemBuilder: buildPathItem),
                      ),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(color: Colors.grey),
                    height: 1,
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: DropTarget(
                      onDragDone: onDragDone,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemBuilder: buildFiles,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}
