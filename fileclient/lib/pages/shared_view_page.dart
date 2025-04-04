import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fileclient/backend/backend.dart';
import 'package:fileclient/event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';
import 'package:path/path.dart' as path;
import '../file_types.dart';
import '../global.dart';
import 'loading.dart';
import 'util/desktop_upload.dart' if (dart.library.html) 'util/web_upload.dart';

import '../icons/filetype1.dart';
import '../util.dart';

class SharedViewPage extends StatefulWidget {
  const SharedViewPage({super.key});
  @override
  State<SharedViewPage> createState() => _SharedViewPageState();
}

class _SharedViewPageState extends State<SharedViewPage> {
  bool _loading = false;
  String _title = "";
  String _sid = "";
  String _code = "";
  final SharedInfo _sharedInfo = SharedInfo();
  String _path = "";
  bool _isLogin = false;
  PackageInformation? _packageInfo;
  UploadInfo? _uploadInfo;
  TransInfo? _downloadInfo;
  final List<FileEntry> _files = [];
  List _pathItems = [];
  @override
  void initState() {
    super.initState();
    _title = Get.parameters.toString();
    _sid = Get.parameters["sid"] ?? "";
    _code = Get.parameters["code"] ?? "";
    Future.delayed(const Duration(milliseconds: 10), () {
      if (!Global.isInit) {
        Global.init().then((_) {
          Backend.getSharedBaseInfo(_sid, _code, onGetSharedBaseInfo, onFailed);
        });
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void onFailed(dynamic ex, String method, String url) {
    Global.logger?.e(ex);
    if (ex is DioException) {
      if (ex.response == null) {
        toastification.show(
            type: ToastificationType.error,
            title: Text("请求失败 $url"),
            pauseOnHover: true,
            description: Text(ex.toString()),
            autoCloseDuration: const Duration(seconds: 5));
        return;
      }
      if (ex.response != null) {
        toastification.show(
            type: ToastificationType.error,
            title: Text(ex.response!.statusMessage.toString()),
            pauseOnHover: true,
            description: Text(ex.response!.data.toString()),
            autoCloseDuration: const Duration(seconds: 5));
        return;
      }
    }
    toastification.show(
        title: Text(ex.toString()),
        pauseOnHover: true,
        description: Text(ex.toString()),
        autoCloseDuration: const Duration(seconds: 5));
  }

  void onGetSharedBaseInfo(Map result) {
    if (result["code"] != 0) {
      if (result["code"] == 1001) {
        if (_code != "") {
          toastification.show(
              title: const Text("请输入正确的共享码"),
              autoCloseDuration: const Duration(seconds: 2));
        }
        _title =
            "${result["data"]["creator"]}创建于${result["data"]["create_at"]}的共享：${result["data"]["name"]}";
        setState(() {
          _isLogin = false;
        });
        return;
      }
      toastification.show(
          title: const Text("获取共享列表失败"),
          description: Text("${result["code"]}(${result["message"]})"),
          autoCloseDuration: const Duration(seconds: 5));
      return;
    }
    _sharedInfo.fromJson(result["data"]);
    _title =
        "${_sharedInfo.creator}创建于${humanizerDatetime(_sharedInfo.createdAt)}的共享：${_sharedInfo.name}";
    setState(() {
      _isLogin = true;
      _loading = true;
    });

    Backend.getSharedFiles(_sid, _code, "/", (result) {
      onGetSharedFiles("/", result);
      setState(() {
        _loading = false;
      });
    }, (a, b, c) {
      onFailed(a, b, c);
      setState(() {
        _loading = false;
      });
    });
  }

  void onGetSharedFiles(String destPath, Map result) {
    if (result["code"] != 0) {
      toastification.show(
          title: const Text("获取共享列表失败"),
          description: Text("${result["code"]}(${result["message"]})"),
          autoCloseDuration: const Duration(seconds: 5));
      return;
    }
    List files = result["data"];
    _files.clear();
    _path = destPath;
    // 解析路径
    _pathItems.clear();
    _pathItems.add({
      "path": destPath,
    });
    while (destPath != '/') {
      destPath = dirName(destPath);

      _pathItems.add({
        "path": destPath,
      });
    }
    _pathItems = _pathItems.reversed.toList();

    for (var item in files) {
      FileEntry entry = FileEntry();
      entry.fromJson(item);
      _files.add(entry);
    }
    setState(() {});
  }

  List<Widget> get pathItems {
    List<Widget> widgets = [const SizedBox(width: 8)];
    for (var item in _pathItems) {
      if (item != _pathItems.first) {
        widgets.add(TextButton(
            onPressed: null,
            style: ButtonStyle(
              padding: WidgetStateProperty.all(EdgeInsets.zero),
              minimumSize: WidgetStateProperty.all(const Size(36, 48)),
            ),
            child: const Icon(Icons.chevron_right)));
      }
      String path = item["path"];
      String name = baseName(path);
      widgets.add(TextButton(
        onPressed: path == _path
            ? null
            : () {
                setState(() {
                  _loading = true;
                });
                Backend.getSharedFiles(_sid, _code, path, (result) {
                  setState(() {
                    _loading = false;
                  });
                  onGetSharedFiles(path, result);
                }, (a, b, c) {
                  setState(() {
                    _loading = false;
                  });
                  onFailed(a, b, c);
                });
              },
        style: ButtonStyle(
          padding: WidgetStateProperty.all(EdgeInsets.zero),
          minimumSize: WidgetStateProperty.all(const Size(36, 48)),
        ),
        child: name == "/" ? const Icon(Icons.home) : Text(name),
      ));
    }
    return widgets;
  }

  Widget get widgetLogin {
    double windowHeight = MediaQuery.of(context).size.height;

    return Center(
      child: SizedBox(
        width: 640,
        child: Column(
          children: [
            SizedBox(height: windowHeight / 3),
            TextField(
              decoration: const InputDecoration(
                hintText: "请输入共享码",
                labelText: "共享码",
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: _code),
              onChanged: (value) => _code = value,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
                onPressed: () {
                  Backend.getSharedBaseInfo(
                      _sid, _code, onGetSharedBaseInfo, onFailed);
                },
                child: const Text("访问")),
          ],
        ),
      ),
    );
  }

  Widget? buildFileItem(BuildContext context, int index) {
    if (index >= _files.length) {
      return const Center(
          child: Text(
        "没有更多数据",
        style: TextStyle(color: Colors.grey),
      ));
    }
    FileItem item = FileItem();
    item.set(_files[index]);
    return ListTile(
      minTileHeight: 32,
      leading: Icon(item.icon),
      title: Text(item.entry.name),
      onTap: () {
        if (item.entry.isDir) {
          String destPath = joinPath([_path, item.entry.name]);
          Backend.getSharedFiles(_sid, _code, destPath,
              (result) => onGetSharedFiles(destPath, result), onFailed);
        } else {
          onDownloadFile(item.entry.name);
        }
      },
      subtitle: Text(humanizerDatetime(item.entry.modifiedAt)),
      trailing: Text(item.entry.isDir ? "" : formatBytes(item.entry.size, 2)),
    );
  }

  // 下载单个文件
  void onDownloadFile(String fileName) async {
    if (_downloadInfo != null) {
      toastification.show(
        title: const Text("有文件正在下载中，请稍后再试"),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return;
    }
    String savePath = fileName;
    if (!kIsWeb) {
      final String? location = await FilePicker.platform.getDirectoryPath(
        dialogTitle: "选择下载目录",
        lockParentWindow: true,
      );
      if (location == null) {
        return;
      }
      savePath = path.join(location, savePath);
    }
    Backend.downloadSharedFile(
        _sid, _code, joinPath([_path, fileName]), savePath,
        (int count, int total) {
      _downloadInfo ??= TransInfo();
      _downloadInfo?.update(count, total);
      setState(() {});
    }, (result) {
      _downloadInfo = null;
      setState(() {});
      toastification.show(
        title: const Text("下载成功"),
        autoCloseDuration: const Duration(seconds: 3),
      );
    }, onFailed);
  }

  // 下载整个文件夹
  void onDownloadPackage(String extName) async {
    String savePath = _sharedInfo.name + extName;
    if (!kIsWeb) {
      final String? location = await FilePicker.platform.getDirectoryPath(
        dialogTitle: "选择下载目录",
        lockParentWindow: true,
      );
      if (location == null) {
        return;
      }
      savePath = path.join(location, savePath);
    }
    Backend.downloadSharedPackage(_sid, _code, extName, _path, savePath,
        (bool isPacking, int count, int total,
            PackageInformation? packageInfo) {
      _packageInfo = packageInfo;
      setState(() {});
    }, (result) {
      _packageInfo = null;
      setState(() {});
      toastification.show(
        title: const Text("下载成功"),
        autoCloseDuration: const Duration(seconds: 3),
      );
    }, onFailed);
  }

  // 上传文件
  void onUploadFile() async {
    if (_uploadInfo != null) {
      toastification.show(
        title: const Text("有文件正在上传中，请稍后再试"),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return;
    }
    String url = "/api/shared/upload";
    onUpload(PageType.serverFiles.index, url,
        {"sid": _sid, "code": _code, "path": _path}, (int count, int total) {
      _uploadInfo ??= UploadInfo();
      _uploadInfo?.update(count, total);
      setState(() {});
    }, (result) {
      _uploadInfo = null;
      setState(() {});
      toastification.show(
        title: const Text("上传成功"),
        autoCloseDuration: const Duration(seconds: 3),
      );
      Backend.getSharedBaseInfo(_sid, _code, onGetSharedBaseInfo, onFailed);
    }, onFailed);
  }

  Widget get widgetFiles {
    bool showProgress = false;
    List<Widget> transInfo = [];
    if (_uploadInfo != null) {
      transInfo.addAll(_uploadInfo!.getWidgets());
      showProgress = true;
    }
    if (_packageInfo != null) {
      transInfo.addAll(_packageInfo!.getWidgets());
      showProgress = true;
    }
    if (_downloadInfo != null) {
      transInfo.addAll(_downloadInfo!.getWidgets());
      showProgress = true;
    }
    DateFormat dateFormat = DateFormat("yyyy-MM-dd HH:mm:ss");
    List<Widget> sharedInfo = [
      Text(
          "到期时间：${_sharedInfo.expireAt == null ? "不限时" : dateFormat.format(_sharedInfo.expireAt!)}"),
    ];
    if (_sharedInfo.canUpload) {
      sharedInfo.add(Text(
          "剩余上传大小：${_sharedInfo.remainUploadSize < 0 ? "无限制" : formatBytes(_sharedInfo.remainUploadSize, 2)}"));
    }
    if (_sharedInfo.canDownload) {
      sharedInfo.add(Text(
          "剩余下载次数：${_sharedInfo.remainCount < 0 ? "无限制" : "${_sharedInfo.remainCount}次"}"));
    }

    return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 32,
              children: sharedInfo,
            ),
          ),
          Visibility(
              visible: showProgress,
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                runAlignment: WrapAlignment.center,
                runSpacing: 16,
                spacing: 16,
                children: transInfo,
              )),
          const SizedBox(height: 2),
          Wrap(children: pathItems),
          Container(
            decoration: const BoxDecoration(color: Colors.grey),
            height: 1,
          ),
          const SizedBox(height: 2),
          Expanded(
              child: ProgressDialog(
            loading: _loading,
            child: ListView.builder(
              itemBuilder: buildFileItem,
              itemCount: _files.length + 1,
            ),
          ))
        ]);
  }

  List<Widget> get getToolbar {
    List<Widget> widgets = [];
    if (_sharedInfo.canDownload) {
      widgets.add(
        IconButton(
          onPressed: () => onDownloadPackage(".zip"),
          tooltip: "当前目录下载为.zip格式",
          icon: const Icon(FileType1.zip),
        ),
      );
      widgets.add(
        IconButton(
          onPressed: () => onDownloadPackage(".tar.gz"),
          tooltip: "当前目录下载为.tar.gz格式",
          icon: const Icon(FileType1.gz),
        ),
      );
    }
    if (_sharedInfo.canUpload) {
      widgets.add(
        IconButton(
          onPressed: onUploadFile,
          icon: const Icon(Icons.upload_file_outlined),
        ),
      );
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: getToolbar,
      ),
      body: _isLogin ? widgetFiles : widgetLogin,
    );
  }
}
