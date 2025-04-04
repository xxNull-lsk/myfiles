import 'dart:convert';

import 'package:event_bus/event_bus.dart';
import 'package:fileclient/global.dart';
import 'package:flutter/material.dart';
import 'util.dart';

class EventBusSingleton {
  static final EventBus _eventBus = EventBus();
  static EventBus get instance => _eventBus;
}

class SharedEntry {
  String name = "";
  String sid = "";
  String code = "";
  String path = "";
  bool canDownload = false;
  bool canUpload = false;
  int maxCount = -1; // 最大访问次数
  int maxUploadSize = -1; // 最大上传大小
  int timeLimited = 0; // 单位天
  int currentCount = 0; // 当前访问次数
  int currentUploadSize = 0; // 当前上传大小
  DateTime createdAt = DateTime.now();
  void fromJson(Map data) {
    name = data["name"];
    sid = data["sid"];
    code = data["code"];
    path = data["path"];
    canDownload = data["can_download"];
    canUpload = data["can_upload"];
    maxCount = data["max_count"];
    maxUploadSize = data["max_upload_size"];
    timeLimited = data["time_limited"];
    currentCount = data["current_count"];
    currentUploadSize = data["current_upload_size"];
    createdAt = DateTime.parse(data["created_at"]);
  }

  Map toJson() {
    return {
      "name": name,
      "sid": sid,
      "code": code,
      "path": path,
      "can_download": canDownload,
      "can_upload": canUpload,
      "max_count": maxCount,
      "max_upload_size": maxUploadSize,
      "time_limited": timeLimited,
      "current_count": currentCount,
      "current_upload_size": currentUploadSize,
      "created_at": createdAt.toString(),
    };
  }
}

class SharedHistoryEntry {
  int id = 0;
  String sid = "";
  String action = "";
  String ip = "";
  Map<String, dynamic> information = {};
  DateTime createdAt = DateTime.now();
  void fromJson(Map data) {
    id = data["id"];
    sid = data["sid"];
    action = data["action"];
    ip = data["ip"];
    information = jsonDecode(data["information"]);
    createdAt = DateTime.parse(data["created_at"]);
  }
}

class UserHistoryEntry {
  int id = 0;
  int userId = 0;
  String userName = "";
  String action = "";
  String ip = "";
  Map<String, dynamic> information = {};
  DateTime createdAt = DateTime.now();
  UserHistoryEntry(Map data) {
    id = data["id"];
    userId = data["user_id"];
    userName = data["user_name"];
    action = data["action"];
    ip = data["ip"];
    information = jsonDecode(data["information"]);
    try {
      createdAt = DateTime.parse(data["created_at"]);
    } catch (ex) {}
  }
}

class PackageInformation {
  DateTime startTime = DateTime.now();
  DateTime? finishTime;
  int finishFileCount = 0;
  int totalFileCount = 0;
  int finishWriteSize = 0;
  int finishSize = 0;
  int totalSize = 0;
  bool finished = false;
  PackageInformation(Map data) {
    fromJson(data);
  }

  void fromJson(Map data) {
    finishFileCount = data["finish_file_count"];
    totalFileCount = data["total_file_count"];
    finishWriteSize = data["finish_write_size"];
    finishSize = data["finish_size"];
    totalSize = data["total_size"];
    finished = data["finished"];
    if (finished) {
      finishTime = DateTime.now();
    } else {
      finishTime = null;
    }
    startTime = DateTime.parse(data["start_time"]);
  }

  String toJson() {
    return jsonEncode({
      "finish_file_count": finishFileCount,
      "total_file_count": totalFileCount,
      "finish_write_size": finishWriteSize,
      "finish_size": finishSize,
      "total_size": totalSize,
      "finished": finished,
      "start_time": startTime.toString(),
    });
  }

  Widget getRow(double maxWidth) {
    return SizedBox(
        width: maxWidth,
        child: Wrap(
          spacing: 16,
          children: getWidgets(maxWidth: maxWidth),
        ));
  }

  List<Widget> getWidgets({double maxWidth = 100}) {
    List<Widget> widgets = [];
    Duration usedTime = DateTime.now().difference(startTime);
    int seconds = usedTime.inSeconds;
    if (seconds < 1) {
      seconds = 1;
    }
    double speed = finishSize / seconds;
    if (speed < 0.001) {
      speed = 0.001;
    }
    double currentProgress = finishSize / totalSize;
    if (finished) {
      Duration usedTime = finishTime!.difference(startTime);
      widgets.add(Text("已用时间：${(formatDuration(usedTime))}"));
      widgets.add(Text("总计大小:${formatBytes(totalSize, 1, fixWidth: true)}"));
      widgets.add(Text("文件数量:$finishFileCount/$totalFileCount"));
      widgets
          .add(Text("处理速度:${formatBytes(speed.toInt(), 1, fixWidth: true)}/s"));
      return widgets;
    }
    Duration leftTime =
        Duration(seconds: ((totalSize - finishSize) / speed).toInt());

    widgets.add(Container(
        alignment: Alignment.center,
        child: SizedBox(
          height: 8,
          width: maxWidth,
          child: LinearProgressIndicator(
            value: currentProgress,
            backgroundColor: Colors.grey,
            valueColor: const AlwaysStoppedAnimation(Colors.orangeAccent),
          ),
        )));
    widgets.add(Text("已用时间：${(formatDuration(usedTime))}"));
    widgets.add(Text("剩余时间:${(formatDuration(leftTime))}"));
    widgets.add(Text("总计大小:${formatBytes(totalSize, 1, fixWidth: true)}"));
    widgets.add(Text("完成大小:${formatBytes(finishSize, 1, fixWidth: true)}"));
    widgets.add(Text("文件数量:$finishFileCount/$totalFileCount"));
    widgets
        .add(Text("处理速度:${formatBytes(speed.toInt(), 1, fixWidth: true)}/s"));
    widgets.add(Text("已经完成:${(currentProgress * 100).toStringAsFixed(2)}%"));
    return widgets;
  }
}

class TransInfo {
  DateTime dtBegin = DateTime.now();
  DateTime? dtFinishTime;
  int total = 1;
  int current = 0;
  double speed = 0.001;
  Duration leftTime = Duration.zero;
  Map result = {};
  bool isFinished = false;
  String ex = "";
  String method = "";
  String url = "";

  TransInfo();
  void update(int current, int total) {
    this.current = current;
    this.total = total;
    if (current == total) {
      isFinished = true;
      dtFinishTime = DateTime.now();
    }
    int seconds = DateTime.now().difference(dtBegin).inSeconds;
    if (seconds < 1) {
      seconds = 1;
    }
    speed = current / seconds;
    if (speed < 0.001) {
      speed = 0.001;
    }
    final left = (total - current) / speed;
    leftTime = Duration(seconds: left.toInt());
  }

  Widget getPortraitWidget() {
    double currentProgress = current / total;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: CircularProgressIndicator(
            value: currentProgress,
            backgroundColor: Colors.grey,
            valueColor: const AlwaysStoppedAnimation(Colors.orangeAccent),
          ),
        ),
        const SizedBox(height: 8),
        Text(
            "${formatBytes(current, 1, fixWidth: true)}/${formatBytes(total, 1, fixWidth: true)}"),
        const SizedBox(height: 8),
        Text("${formatBytes(speed.toInt(), 1, fixWidth: true)}/s"),
        const SizedBox(height: 8),
        Text(formatDuration(leftTime)),
      ],
    );
  }

  Widget getRow(double maxWidth) {
    double currentProgress = current / total;
    if (isFinished) {
      Duration used = dtFinishTime!.difference(dtBegin);
      return SizedBox(
          width: maxWidth,
          child: Wrap(
            spacing: 16,
            children: [
              Text("用时:${formatDuration(used)}"),
              Text("大小:${formatBytes(total, 1, fixWidth: true)}"),
              Text("速度:${formatBytes(speed.toInt(), 1, fixWidth: true)}/s"),
            ],
          ));
    }
    return SizedBox(
        width: maxWidth,
        child: Wrap(
          spacing: 16,
          children: [
            SizedBox(
                height: 8,
                width: maxWidth,
                child: LinearProgressIndicator(
                  value: currentProgress,
                  backgroundColor: Colors.grey,
                  valueColor: const AlwaysStoppedAnimation(Colors.orangeAccent),
                )),
            Text("剩余用时:${formatDuration(leftTime)}"),
            Text("传输速度:${formatBytes(speed.toInt(), 1, fixWidth: true)}/s"),
            Text(
                "文件大小:${formatBytes(current, 1, fixWidth: true)}/${formatBytes(total, 1, fixWidth: true)}"),
          ],
        ));
  }

  Widget getWidget() {
    Duration used = DateTime.now().difference(dtBegin);
    double currentProgress = current / total;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
            height: 8,
            width: 480,
            child: LinearProgressIndicator(
              value: currentProgress,
              backgroundColor: Colors.grey,
              valueColor: const AlwaysStoppedAnimation(Colors.orangeAccent),
            )),
        const SizedBox(height: 8),
        Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(1),
          },
          children: [
            TableRow(children: [
              Text("已用时间:${formatDuration(used)}"),
              Text("剩余时间:${formatDuration(leftTime)}"),
            ]),
            TableRow(children: [
              Text("总计大小:${formatBytes(total, 1, fixWidth: true)}"),
              Text("完成大小:${formatBytes(current, 1, fixWidth: true)}"),
            ]),
            TableRow(children: [
              Text("传输速度:${formatBytes(speed.toInt(), 1, fixWidth: true)}/s"),
              Text("已经完成:${(currentProgress * 100).toStringAsFixed(2)}%"),
            ]),
          ],
        )
      ],
    );
  }

  List<Widget> getWidgets() {
    List<Widget> widgets = [];
    Duration used = DateTime.now().difference(dtBegin);
    if (isFinished) {
      widgets.add(Text("用时:${formatDuration(used)}"));
      widgets.add(Text("大小:${formatBytes(total, 1, fixWidth: true)}"));
      widgets
          .add(Text("速度:${formatBytes(speed.toInt(), 1, fixWidth: true)}/s"));
      return widgets;
    }
    // 格式化时间
    widgets.add(Text("已用时间:${formatDuration(used)}"));
    widgets.add(Text("剩余时间:${formatDuration(leftTime)}"));
    widgets.add(Text("总计大小:${formatBytes(total, 1, fixWidth: true)}"));
    widgets.add(Text("完成大小:${formatBytes(current, 1, fixWidth: true)}"));
    widgets
        .add(Text("传输速度:${formatBytes(speed.toInt(), 1, fixWidth: true)}/s"));
    double currentProgress = current / total;
    widgets.add(Text("已经完成:${(currentProgress * 100).toStringAsFixed(2)}%"));
    widgets.add(Container(
        alignment: Alignment.center,
        child: SizedBox(
          height: 8,
          width: 100,
          child: LinearProgressIndicator(
            value: currentProgress,
            backgroundColor: Colors.grey,
            valueColor: const AlwaysStoppedAnimation(Colors.orangeAccent),
          ),
        )));
    return widgets;
  }
}

class UploadInfo {
  DateTime dtBegin = DateTime.now();
  int total = 1;
  int current = 0;
  double speed = 0.001;
  Duration leftTime = Duration.zero;
  UploadInfo();

  void update(int current, int total) {
    this.current = current;
    this.total = total;
    int seconds = DateTime.now().difference(dtBegin).inSeconds;
    if (seconds < 1) {
      seconds = 1;
    }
    speed = current / seconds;
    if (speed < 0.001) {
      speed = 0.001;
    }
    final left = (total - current) / speed;
    leftTime = Duration(seconds: left.toInt());
  }

  List<Widget> getWidgets() {
    List<Widget> widgets = [];
    Duration used = DateTime.now().difference(dtBegin);
    // 格式化时间
    widgets.add(Text("已用时间:${formatDuration(used)}"));
    widgets.add(Text("剩余时间:${formatDuration(leftTime)}"));
    widgets.add(Text("总计大小:${formatBytes(total, 1, fixWidth: true)}"));
    widgets.add(Text("完成大小:${formatBytes(current, 1, fixWidth: true)}"));
    widgets
        .add(Text("上传速度:${formatBytes(speed.toInt(), 1, fixWidth: true)}/s"));
    double currentProgress = current / total;
    widgets.add(Text("已经完成:${(currentProgress * 100).toStringAsFixed(2)}%"));

    widgets.add(Container(
        alignment: Alignment.center,
        child: SizedBox(
          height: 8,
          width: 100,
          child: LinearProgressIndicator(
            value: currentProgress,
            backgroundColor: Colors.grey,
            valueColor: const AlwaysStoppedAnimation(Colors.orangeAccent),
          ),
        )));
    return widgets;
  }
}

class SharedInfo {
  String sid = "";
  String name = "";
  bool canDownload = false;
  bool canUpload = false;
  int timeLimited = 0; // =0 表示没有限制
  int remainCount = 0; // <0 表示没有限制
  int remainUploadSize = 0; // <0 表示没有限制
  String creator = "";
  DateTime createdAt = DateTime.now();
  DateTime? expireAt;
  SharedInfo();

  void fromJson(Map data) {
    sid = data["sid"];
    name = data["name"];
    canDownload = data["can_download"];
    canUpload = data["can_upload"];
    timeLimited = data["time_limited"];
    remainCount = data["remain_count"];
    remainUploadSize = data["remain_upload_size"];
    creator = data["creator"];
    createdAt = DateTime.parse(data["create_at"]);
    if (timeLimited > 0) {
      expireAt = createdAt.add(Duration(days: timeLimited));
    }
  }
}

class EventSelectFile {
  final int pageID;
  EventSelectFile(this.pageID);
}

class EventToolbar {
  final int pageID;
  final String name;
  EventToolbar(this.pageID, this.name);
}

class EventRefreshFavorites {
  EventRefreshFavorites();
}

class EventGotoPath {
  final int pageID;
  final String path;
  EventGotoPath(this.pageID, this.path);
}

class EventUpdateTitle {
  final int pageID;
  EventUpdateTitle(this.pageID);
}

enum ClipboardAction {
  copy,
  cut,
}

class EventClipboard {
  final int pageID;
  final String path;
  final ClipboardAction action;
  EventClipboard(this.pageID, this.path, this.action);
}

enum SlideType {
  toLeft,
  toRight,
}

class EventGestureDetector {
  final SlideType slideType;
  EventGestureDetector(this.slideType);
}

class EventTaskUpdate {
  final dynamic task;
  EventTaskUpdate(this.task);
}

class EventTasksChanged {
  final dynamic task;
  final bool isAdd;
  EventTasksChanged(this.isAdd, this.task);
}

class XtermConfig {
  late String title;
  late String host;
  late int port;
  late String username;
  late String password;
  late String authKey;
  late String checkin;
  XtermConfig(Map data) {
    title = data["title"] ?? "";
    host = data["host"] ?? "";
    port = data["port"] ?? 0;
    username = data["username"] ?? "";
    password = data["password"] ?? "";
    authKey = data["auth_key"] ?? "";
    checkin = data["checkin"] ?? "";
    if (Global.userInfo.settings.containsKey("environments")) {
      String envs = Global.userInfo.settings["environments"]!;
      jsonDecode(envs).forEach((key, value) {
        host = host.replaceAll("\${env:$key}", value);
        username = username.replaceAll("\${env:$key}", value);
        password = password.replaceAll("\${env:$key}", value);
        authKey = authKey.replaceAll("\${env:$key}", value);
        checkin = checkin.replaceAll("\${env:$key}", value);
      });
    }
    if (checkin.isNotEmpty) {
      checkin = checkin.replaceAll("\${host}", host);
    }
  }
}

class EventXterm {
  final int pageID;
  final XtermConfig cfg;
  final String xtermFilePath;
  EventXterm(this.pageID, this.cfg, this.xtermFilePath);
}

enum XtermAction {
  changedTitle,
  changedPath,
  closed,
}

class EventXtermChanged {
  final int pageID;
  final XtermAction action;
  final String value;
  EventXtermChanged(this.pageID, this.action, this.value);
}

class EventXtermToolbar {
  final int pageID;
  final String name;
  EventXtermToolbar(this.pageID, this.name);
}

class EventSshFileToolbar {
  final int pageID;
  final String name;
  EventSshFileToolbar(this.pageID, this.name);
}

enum WatchEventType {
  add,
  delete,
  modified,
}

class EventWatchFileChanged {
  final int pageID;
  final String remoteFilePath;
  final String localFilePath;
  final String fileType;
  final WatchEventType type;
  EventWatchFileChanged(
      this.pageID,
      this.localFilePath, this.remoteFilePath, this.fileType, this.type);
}
