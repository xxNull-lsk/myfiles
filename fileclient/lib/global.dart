import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:fileclient/backend/task_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

import 'backend/backend.dart';
import 'backend/dio_util.dart';
import 'file_types.dart';
import 'log.dart';
import 'pages/home.dart';

import 'package:universal_html/html.dart' as html;

import 'package:logger/logger.dart';

import 'pages/mode/ssh.dart';
import 'watcher.dart';

class UserSettingEntry {
  int id = 0;
  int userId = 0;
  String key = "";
  String value = "";

  void fromJson(Map<String, dynamic> json) {
    id = json["id"];
    userId = json["user_id"];
    key = json["key"];
    value = json["value"];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'key': key,
      'value': value,
    };
  }
}

enum OpenFileMode {
  auto,
  singleClickToOpen,
  doubleClickToOpen,
}

enum OpenXtermAsTerminal {
  ask,
  always,
  nerver,
}

enum AutoUploadFile {
  ask,
  always,
  nerver,
}

class UserInfo {
  int id = 0;
  String name = "";
  String password = "";
  String email = "";
  bool enabled = false;
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
  DateTime lastLoginAt = DateTime.now();
  String rootDir = "";
  bool isAdmin = false;
  bool showDotFiles = false;
  OpenFileMode openFileMode = OpenFileMode.auto;
  OpenXtermAsTerminal openXtermAsTerminal = OpenXtermAsTerminal.ask;
  AutoUploadFile autoUploadFile = AutoUploadFile.ask;
  Map<String, dynamic> settings = {};
  void fromJson(Map<String, dynamic> json) {
    id = json['id'] ?? "";
    name = json['name'] ?? "";
    password = json['password'] ?? "";
    email = json['email'] ?? "";
    enabled = json['enabled'] ?? false;
    if (json['created_at'] != null && json['created_at'] != "") {
      createdAt = DateTime.parse(json['created_at']);
    }
    if (json['updated_at'] != null && json['updated_at'] != "") {
      updatedAt = DateTime.parse(json['updated_at']);
    }
    if (json['last_login_at'] != null && json['last_login_at'] != "") {
      lastLoginAt = DateTime.parse(json['last_login_at']);
    }
    rootDir = json['root_dir'] ?? "";
    isAdmin = json['is_admin'] ?? false;
    showDotFiles = json['show_dot_files'] ?? false;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'password': password,
      'email': email,
      'enabled': enabled,
      'created_at': createdAt.toString(),
      'updated_at': updatedAt.toString(),
      'last_login_at': lastLoginAt.toString(),
      'root_dir': rootDir,
      'is_admin': isAdmin,
      'show_dot_files': showDotFiles,
    };
  }

  void checkOpenFileMode() {
    for (var element in OpenFileMode.values) {
      if (element.name == Global.userInfo.settings["open_file_mode"]) {
        openFileMode = element;
        break;
      }
    }
    if (openFileMode == OpenFileMode.auto) {
      if (kIsWeb) {
        openFileMode = OpenFileMode.singleClickToOpen;
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        openFileMode = OpenFileMode.doubleClickToOpen;
      } else {
        openFileMode = OpenFileMode.singleClickToOpen;
      }
    }
  }

  void initSetting(dynamic json) {
    settings = {};
    if (json != null) {
      settings = json;
    }
    if (!settings.containsKey("open_file_mode")) {
      settings["open_file_mode"] = OpenFileMode.auto.name;
    }
    checkOpenFileMode();
    if (!settings.containsKey("open_xterm_as_terminal")) {
      settings["open_xterm_as_terminal"] = OpenXtermAsTerminal.ask.name;
    }
    openXtermAsTerminal = OpenXtermAsTerminal.values.firstWhere(
        (element) => element.name == settings["open_xterm_as_terminal"]);
    if (!settings.containsKey("auto_upload_file")) {
      settings["auto_upload_file"] = AutoUploadFile.ask.name;
    }
    autoUploadFile = AutoUploadFile.values
        .firstWhere((element) => element.name == settings["auto_upload_file"]);
  }

  Future<void> changeUserSetting(String key, String value,
      HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) {
    return Backend.changeUserSetting({
      "user_id": id,
      "key": key,
      "value": value,
    }, (result) {
      if (result["code"] == 0) {
        Global.userInfo.settings[key] = value;
        switch (key) {
          case "open_file_mode":
            checkOpenFileMode();
            break;
          case "open_xterm_as_terminal":
            openXtermAsTerminal = OpenXtermAsTerminal.values.firstWhere(
                (element) =>
                    element.name == settings["open_xterm_as_terminal"]);
            break;
          case "auto_upload_file":
            autoUploadFile = AutoUploadFile.values.firstWhere(
                (element) => element.name == settings["auto_upload_file"]);
            break;
        }
      }
      onSucceed(result);
    }, onFailed);
  }
}

class VersionInfo {
  String version = "";
  String commit = "";
  String time = "";
  String name = "";
  String url = "";
  bool installMode = false;
  void fromJson(Map<String, dynamic> json) {
    version = json['version'] ?? "";
    commit = json['commit'] ?? "";
    time = json['time'] ?? "";
    name = json['name'] ?? "";
    url = json['url'] ?? "";
    installMode = json['install_mode'] ?? false;
  }
}

enum ShowMode {
  unknown, // 未知
  landScape, // 横屏
  portrait, // 竖屏
}

enum SortBy {
  sortBySize,
  sortByName,
  sortByType,
  sortByModified,
  sortByCreated,
}

class PageData {
  String path = "";
  int pageID = -1;
  int selectedCount = 0;
  SortBy sortBy = SortBy.sortByType; // 排序方式
  bool sortDesc = false; // false: 升序 true: 降序
  List<FileItem> fileItems = [];
  PageData(this.path, this.pageID, this.selectedCount);
}

class Global {
  static String username = '';
  static String password = '';
  static String sessionId = '';
  static String token = '';
  static UserInfo userInfo = UserInfo();
  static String backendURL = "http://127.0.0.1:8080";
  static GlobalKey<HomePageState> filesKey = GlobalKey();
  static VersionInfo serverVersion = VersionInfo();
  static PackageInfo? clientVersion;
  static ShowMode showMode = ShowMode.unknown;
  static Logger? logger;
  static String logFile = '';
  static Level logLevel = Level.info;
  static bool isInit = false;
  static bool allowSelfCertificate = true;
  static String cachePath = "";
  static TaskManager? taskManager;
  static Watcher watcher = Watcher();
  static Map<int, Ssh> ssh = {};
  static int currentPageID = -1;
  static Map<int, PageData> filePages = {};
  static List favoriteItems = [];
  static int _nextPageID = -1;
  static bool isShowingTask = false;

  static String getPagePath(int pageID) {
    return filePages[pageID]?.path ?? "/";
  }

  static int allowPageID() {
    return _nextPageID--;
  }

  static Future<void> init() async {
    if (isInit) {
      return;
    }
    clientVersion = await PackageInfo.fromPlatform();
    if (!kIsWeb) {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        String startPath = p.dirname(Platform.resolvedExecutable);
        String cfgFile = p.join(startPath, "cfg.json");
        if (File(cfgFile).existsSync()) {
          String cfgContent = File(cfgFile).readAsStringSync();
          Map<String, dynamic> cfg = jsonDecode(cfgContent);
          backendURL = cfg["backendURL"] ?? backendURL;
          allowSelfCertificate =
              cfg["allowSelfCertificate"] ?? allowSelfCertificate;
        }
      }
    }
    clearCache();
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int levelValue = prefs.getInt("logLevel") ?? Level.info.value;
      for (var element in Level.values) {
        if (element.value == levelValue) {
          logLevel = element;
        }
      }
      await initLog();
      username = prefs.getString("username") ?? "";
      password = prefs.getString("password") ?? "";
      token = prefs.getString("token") ?? "";
      sessionId = prefs.getString("sessionId") ?? "";
      backendURL = prefs.getString("backendURL") ?? backendURL;
      logger?.i(
          "Load cfg: username: $username token: $token sessionId: $sessionId backendURL: $backendURL");
      isInit = true;
    } catch (ex) {
      logger?.e(ex);
      print(ex);
    }
    if (kIsWeb && !kDebugMode) {
      var url = html.window.location.href;
      int start = 0;
      if (url.startsWith("http://") || url.startsWith("https://")) {
        start = url.indexOf("//") + 2;
      }
      backendURL = url.substring(0, url.indexOf("/", start));
    }
  }

  static int get cacheSize {
    if (kIsWeb) {
      return 0;
    }
    int size = 0;
    Directory directoryTemp = Directory(cachePath);
    if (directoryTemp.existsSync()) {
      directoryTemp.listSync(recursive: true).forEach((element) {
        size += element.statSync().size;
      });
    }
    return size;
  }

  static Future<void> clearCache() async {
    if (kIsWeb) {
      return;
    }
    if (cachePath.isEmpty) {
      Directory? directoryTemp = await getApplicationCacheDirectory();
      if (Platform.isAndroid) {
        directoryTemp = await getExternalStorageDirectory();
      }
      cachePath = p.join(directoryTemp!.path, "fileclient");
    }
    Directory directoryCache = Directory(cachePath);
    if (directoryCache.existsSync()) {
      directoryCache.deleteSync(recursive: true);
    }
    directoryCache.createSync(recursive: true);
  }

  static Future<void> initLog() async {
    var filter = ProductionFilter();
    LogOutput output;
    filter.level = logLevel;
    if (kIsWeb) {
      if (!kDebugMode && logLevel != Level.debug) {
        return;
      }
      output = ConsoleOutput();
    } else {
      final Directory appDocumentsDir = await getApplicationCacheDirectory();
      logFile = join(appDocumentsDir.path, "app.log");
      if (logLevel == Level.debug) {
        output =
            MultiOutput([FileOutput(file: File(logFile)), ConsoleOutput()]);
      } else {
        output = FileOutput(file: File(logFile));
      }
    }
    logger = Logger(
        filter: filter, output: output, printer: MyLogPrinter(printTime: true));

    logger?.i("=================================================");
  }

  static Future<bool> initVersionAsync() async {
    if (Global.serverVersion.commit.isNotEmpty) {
      return true;
    }
    Response response = await Backend.getVersionAsync();
    if (response.statusCode != 200) {
      return false;
    }
    Map result = response.data;
    if (result["code"] != 0) {
      return false;
    }
    Global.serverVersion.fromJson(result["data"]);
    return true;
  }

  static void initVersion(HttpSucceedCallback onSucceed) {
    if (Global.serverVersion.commit.isNotEmpty) {
      return;
    }
    Backend.getVersion((result) {
      if (result["code"] != 0) {
        return;
      }
      Global.serverVersion.fromJson(result["data"]);
      onSucceed(result);
    }, (a, b, c) {});
  }

  static Future<void> save() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString("username", username);
      prefs.setString("password", password);
      prefs.setString("token", token);
      prefs.setString("sessionId", sessionId);
      prefs.setString("backendURL", backendURL);
      prefs.setInt("logLevel", logLevel.value);
      logger?.i(
          "Save cfg: username: $username token: $token sessionId: $sessionId backendURL: $backendURL\n");
    } catch (ex) {
      logger?.e(ex);
    }
  }

  /// 授予定位权限返回true， 否则返回false
  static Future<bool> requestExternalStoragePermission() async {
    if (kIsWeb) {
      return true;
    }
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }
    //获取当前的权限
    var status = await Permission.manageExternalStorage.status;
    if (status == PermissionStatus.granted) {
      //已经授权
      return true;
    } else {
      //未授权则发起一次申请
      status = await Permission.manageExternalStorage.request();
      if (status == PermissionStatus.granted) {
        return true;
      } else {
        return false;
      }
    }
  }

  static Future<bool> requestStoragePermission() async {
    if (kIsWeb) {
      return true;
    }
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }
    //获取当前的权限
    var status = await Permission.storage.status;
    if (status == PermissionStatus.granted) {
      //已经授权
      return true;
    } else {
      //未授权则发起一次申请
      status = await Permission.storage.request();
      if (status == PermissionStatus.granted) {
        return true;
      } else {
        return false;
      }
    }
  }

  static Future<bool> requestInstallPermission() async {
    if (kIsWeb) {
      return true;
    }
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }
    //获取当前的权限
    var status = await Permission.requestInstallPackages.status;
    if (status == PermissionStatus.granted) {
      //已经授权
      return true;
    } else {
      //未授权则发起一次申请
      status = await Permission.requestInstallPackages.request();
      if (status == PermissionStatus.granted) {
        return true;
      } else {
        return false;
      }
    }
  }
}

enum PageType {
  serverFiles,
  shared,
  settings,
  xterm,
}
