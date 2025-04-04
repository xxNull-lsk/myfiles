import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:fileclient/event.dart';
import 'package:fileclient/util.dart';
import 'package:flutter/foundation.dart';

import '../global.dart';
import 'backend.dart';

enum TaskType {
  upload,
  download,
  package,
}

extension TaskTypeName on TaskType {
  String get name {
    switch (this) {
      case TaskType.upload:
        return '上传';
      case TaskType.download:
        return '下载';
      case TaskType.package:
        return '打包';
    }
  }
}

enum TransStatus {
  waitting,
  starting,
  running,
  succeed,
  failed,
}

extension TransStatusName on TransStatus {
  String get name {
    switch (this) {
      case TransStatus.waitting:
        return '等待中';
      case TransStatus.starting:
        return '开始传输';
      case TransStatus.running:
        return '传输中';
      case TransStatus.succeed:
        return '成功';
      case TransStatus.failed:
        return '失败';
    }
  }
}

class TransTaskItem {
  int pageID;
  String backendTaskId = "";
  Isolate? isolate;
  TaskType taskType;
  final String taskId = generateRandomString(16);
  final String localFilePath;
  final String remoteFilePath;
  Map<String, dynamic>? params;
  TransInfo? transInfo;
  PackageInformation? packageInfo;
  TransStatus status = TransStatus.waitting;
  TransTaskItem(
      {required this.pageID,
      required this.taskType,
      required this.localFilePath,
      required this.remoteFilePath,
      this.params});

  void onRecvPackageMessage(TransStatus status, dynamic message) {
    switch (status) {
      case TransStatus.waitting:
        break;
      case TransStatus.starting:
        backendTaskId = message[0];
        Global.logger
            ?.i("${taskType.name} $remoteFilePath started!pid=$backendTaskId");
        break;
      case TransStatus.running:
        packageInfo ??= PackageInformation(message[0]);
        packageInfo?.fromJson(message[0]);
        EventBusSingleton.instance.fire(EventTaskUpdate(this));
        break;
      case TransStatus.succeed:
        EventBusSingleton.instance.fire(EventTaskUpdate(this));
        taskType = TaskType.download;
        Global.logger
            ?.i("${taskType.name} $remoteFilePath succeed!pid=$backendTaskId");
        break;
      case TransStatus.failed:
        transInfo?.ex = message[0];
        transInfo?.method = message[1];
        transInfo?.url = message[2];
        EventBusSingleton.instance.fire(EventTaskUpdate(this));
        Global.logger?.e(
            "${taskType.name} $remoteFilePath failed! ex:${transInfo?.ex}pid=$backendTaskId");
        EventBusSingleton.instance.fire(EventTaskUpdate(this));
        break;
    }
  }

  void onRecvMessage(TransStatus status, dynamic message) {
    this.status = status;
    if (taskType == TaskType.package) {
      onRecvPackageMessage(status, message);
      return;
    }
    switch (status) {
      case TransStatus.waitting:
        break;
      case TransStatus.starting:
        transInfo ??= TransInfo();
        transInfo!.update(0, message[0]);
        backendTaskId = message[1];
        break;
      case TransStatus.running:
        int curr = message[0];
        int total = message[1];
        transInfo ??= TransInfo();
        transInfo!.update(curr, total);
        EventBusSingleton.instance.fire(EventTaskUpdate(this));
        break;
      case TransStatus.succeed:
        transInfo?.result = message[0];
        EventBusSingleton.instance.fire(EventTaskUpdate(this));
        if (taskType == TaskType.upload) {
          EventBusSingleton.instance.fire(EventGotoPath(pageID, ""));
        }
        Global.logger?.i("${taskType.name} $remoteFilePath succeed!");
        break;
      case TransStatus.failed:
        transInfo?.ex = message[0];
        transInfo?.method = message[1];
        transInfo?.url = message[2];
        EventBusSingleton.instance.fire(EventTaskUpdate(this));
        Global.logger
            ?.e("${taskType.name} $remoteFilePath failed! ex:${transInfo?.ex}");
        break;
    }
  }
}

class TaskManager {
  List<TransTaskItem> tasks = [];
  ReceivePort receivePort = ReceivePort();
  int maxRunningCount = 1;
  late StreamSubscription<EventTasksChanged> listenEventTasksChanged;

  TaskManager() {
    Global.logger?.i("start task manager...");
    receivePort.listen(onRecvMessageFromThread);

    listenEventTasksChanged =
        EventBusSingleton.instance.on<EventTasksChanged>().listen((evnt) {
      onCheckTasks();
    });
  }

  void dispose() {
    Global.logger?.i("dispose task manager...");
    receivePort.close();
    listenEventTasksChanged.cancel();
  }

  void removeTask(TransTaskItem task) {
    Global.logger?.i("remove task ${task.taskId} from tasks...");
    // 如果是下载任务，并且没有完成，删除本地文件
    if ((task.transInfo == null || !task.transInfo!.isFinished)) {
      if (task.taskType == TaskType.download) {
        File file = File(task.localFilePath);
        file.deleteSync();
      } else {
        // TODO: 如果是上传任务，删除上传任务
      }
    }
    task.isolate?.kill();
    tasks.remove(task);
    EventBusSingleton.instance.fire(EventTasksChanged(false, task));
  }

  bool addTask(TransTaskItem task) {
    Global.logger?.i(
        "add task ${task.taskType.name} ${task.remoteFilePath} to tasks...");
    tasks.add(task);
    EventBusSingleton.instance.fire(EventTasksChanged(true, task));
    return true;
  }

  Future<void> onCheckTasks() async {
    Global.logger?.i("check tasks...");
    if (tasks.isEmpty) {
      return;
    }

    TransTaskItem? task;
    int runningCount = 0;
    for (var item in tasks) {
      if (item.status == TransStatus.running) {
        runningCount++;
        continue;
      }
      if (task == null && item.status == TransStatus.waitting) {
        task = item;
      }
    }
    if (runningCount >= maxRunningCount) {
      return;
    }
    if (task == null) {
      return;
    }

    task.status = TransStatus.running;
    Global.logger?.i("start ${task.taskType.name} ${task.remoteFilePath}...");
    switch (task.taskType) {
      case TaskType.download:
        task.isolate = await Isolate.spawn(downloadThread, [
          receivePort.sendPort,
          Global.backendURL,
          Global.token,
          Global.sessionId,
          task.taskId,
          task.remoteFilePath,
          task.localFilePath,
        ]);
        break;
      case TaskType.upload:
        task.isolate = await Isolate.spawn(uploadThread, [
          receivePort.sendPort,
          Global.backendURL,
          Global.token,
          Global.sessionId,
          task.taskId,
          task.localFilePath,
          task.remoteFilePath,
          task.params,
        ]);
        break;
      case TaskType.package:
        task.isolate = await Isolate.spawn(downloadPackageThread, [
          receivePort.sendPort,
          Global.backendURL,
          Global.token,
          Global.sessionId,
          task.taskId,
          task.remoteFilePath,
          task.localFilePath,
          task.params!["file_type"],
        ]);
        break;
    }
  }

  void onRecvMessageFromThread(dynamic message) {
    if (message is! List) {
      return;
    }
    if (message.isEmpty) {
      return;
    }

    String taskId = message[0];
    TransStatus status = message[1];
    dynamic taskItem;
    for (var item in tasks) {
      if (item.taskId == taskId) {
        taskItem = item;
        break;
      }
    }
    if (taskItem == null) {
      return;
    }
    if (taskItem is TransTaskItem) {
      taskItem.onRecvMessage(status, message.sublist(2));
    }
    if (status == TransStatus.succeed || status == TransStatus.failed) {
      onCheckTasks();
    }
  }

  static Future<void> downloadThread(List message) async {
    SendPort sendPort = message[0];
    Global.backendURL = message[1];
    Global.token = message[2];
    Global.sessionId = message[3];
    String taskId = message[4];
    String remoteFilePath = message[5];
    String localFilePath = message[6];
    return Backend.downloadFile(remoteFilePath, localFilePath, (curr, total) {
      sendPort.send([taskId, TransStatus.running, curr, total]);
    }, (result) {
      sendPort.send([taskId, TransStatus.succeed, result]);
    }, (ex, method, url) {
      sendPort.send([taskId, TransStatus.failed, ex.toString(), method, url]);
    });
  }

  static Future<void> uploadThread(List message) async {
    SendPort sendPort = message[0];
    Global.backendURL = message[1];
    Global.token = message[2];
    Global.sessionId = message[3];
    String taskId = message[4];
    String localFilePath = message[5];
    String remoteFilePath = message[6];
    Map<String, dynamic>? params = message[7];

    Response response = await Backend.createUploadFileTask(
        remoteFilePath, params!, localFilePath);
    if (response.statusCode != 200) {
      sendPort.send([
        taskId,
        TransStatus.failed,
        "request failed!${response.statusCode}: ${response.statusMessage}",
        "createUploadFileTask",
        remoteFilePath
      ]);
    }
    Map result = response.data;
    if (result["code"] != 0) {
      sendPort.send([
        taskId,
        TransStatus.failed,
        "error in server.${result["code"]}: ${result["message"]}",
        "createUploadFileTask",
        remoteFilePath
      ]);
      return;
    }
    await onUploadChunk(taskId, sendPort, result, localFilePath);
  }

  static Future<void> onUploadChunk(
      String taskId, SendPort sendPort, Map result, String filePath) async {
    if (result["code"] != 0) {
      sendPort.send([
        taskId,
        TransStatus.failed,
        "CreateUploadFileTask failed!${result["code"]}: ${result["message"]}",
        "CreateUploadFileTask",
        ""
      ]);
      return;
    }

    String uploadTaskId = result["data"]["upload_task_id"];
    File file = File(filePath);
    int fileSize = file.lengthSync();
    int chunkSize = 1024 * 1024 * 10;
    int finishSize = 0;
    bool failed = false;
    sendPort.send([taskId, TransStatus.starting, fileSize, uploadTaskId]);
    var reader = file.openSync();
    while (finishSize < fileSize && !failed) {
      int readSize = chunkSize;
      if (finishSize + readSize >= fileSize) {
        readSize = fileSize - finishSize;
      }
      Uint8List bytes = reader.readSync(readSize);
      Response response = await Backend.uploadFileChunk(
          uploadTaskId, bytes, finishSize, (finish, total) {
        if (failed) {
          return;
        }
        sendPort
            .send([taskId, TransStatus.running, finishSize + finish, fileSize]);
      });
      if (response.statusCode != 200) {
        failed = true;
        sendPort.send([
          taskId,
          TransStatus.failed,
          "request failed!${response.statusCode}: ${response.statusMessage}",
          "UploadChunk",
          ""
        ]);
        reader.closeSync();
        return;
      }
      Map result = response.data;
      if (result["code"] != 0) {
        failed = true;
        sendPort.send([
          taskId,
          TransStatus.failed,
          "UploadChunk failed!${result["code"]}: ${result["message"]}",
          "UploadChunk",
          ""
        ]);
        reader.closeSync();
        return;
      }
      finishSize += readSize;
      if (finishSize >= fileSize) {
        sendPort.send([taskId, TransStatus.succeed, result]);
      }
    }
    reader.closeSync();
  }

  static void downloadPackageThread(List message) async {
    SendPort sendPort = message[0];
    Global.backendURL = message[1];
    Global.token = message[2];
    Global.sessionId = message[3];
    String taskId = message[4];
    String remoteFilePath = message[5];
    String localFilePath = message[6];
    String fileType = message[7];

    // 创建打包任务
    Response response = await Backend.createDownloadPackageAsync(
        fileType, remoteFilePath, localFilePath);
    if (response.statusCode != 200) {
      sendPort.send([
        taskId,
        TransStatus.failed,
        "request failed!${response.statusCode}: ${response.statusMessage}",
        "createDownloadPackageAsync",
        remoteFilePath
      ]);
    }

    Map result = response.data;
    if (result["code"] != 0) {
      sendPort.send([
        taskId,
        TransStatus.failed,
        "error in server.${result["code"]}: ${result["message"]}",
        "createDownloadPackageAsync",
        remoteFilePath
      ]);
      return;
    }
    String pid = result["pid"];
    sendPort.send([taskId, TransStatus.starting, pid]);

    // 查询打包进度
    while (true) {
      Response response = await Backend.queryDownloadPackageStatusAsync(pid);
      if (response.statusCode != 200) {
        sendPort.send([
          taskId,
          TransStatus.failed,
          "request failed!${response.statusCode}: ${response.statusMessage}",
          "queryDownloadPackageStatusAsync",
          remoteFilePath
        ]);
      }
      Map result = response.data;
      if (result["code"] != 0) {
        sendPort.send([
          taskId,
          TransStatus.failed,
          "error in server.${result["code"]}: ${result["message"]}",
          "queryDownloadPackageStatusAsync",
          remoteFilePath
        ]);
        return;
      }
      sendPort.send([taskId, TransStatus.running, result["data"]]);

      if (result["data"]["finished"]) {
        break;
      }
      sleep(Duration(seconds: 1));
    }
    sendPort.send([taskId, TransStatus.succeed]);
    // 开在后台下载
    await Backend.getDownloadPackage(pid, localFilePath, (curr, total) {
      sendPort.send([taskId, TransStatus.running, curr, total]);
    }, (result) {
      sendPort.send([taskId, TransStatus.succeed, result]);
    }, (ex, method, url) {
      sendPort.send([taskId, TransStatus.failed, ex.toString(), method, url]);
    });
  }
}
