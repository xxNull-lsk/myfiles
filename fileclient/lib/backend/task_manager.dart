import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:fileclient/event.dart';
import 'package:fileclient/util.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../file_types.dart';
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

class TransProgress {
  int curr = 0;
  int total = 0;
  String currFile = "";
  Map result = {};
  Map<String, Map> results = {};
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
  final String urlUpload;
  final FileItem? remoteFileItem;
  Map<String, dynamic>? params;
  TransInfo? transInfo;
  PackageInformation? packageInfo;
  TransStatus status = TransStatus.waitting;
  TransTaskItem(
      {required this.pageID,
      required this.taskType,
      required this.localFilePath,
      required this.remoteFilePath,
      required this.urlUpload,
      this.remoteFileItem,
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

  void clearFinishedTasks() {
    Global.logger?.i("clear finished tasks...");
    tasks.removeWhere((task) =>
        task.status == TransStatus.succeed ||
        task.status == TransStatus.failed);
    EventBusSingleton.instance.fire(EventTasksChanged(false, null));
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
          task.remoteFileItem?.entry.toMap(),
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
          task.urlUpload,
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
    FileEntry remoteFileEntry = FileEntry();
    remoteFileEntry.fromJson(message[7]);
    if (remoteFileEntry.isDir) {
      TransProgress progress = TransProgress();
      // 计算目录下的所有文件大小的和
      progress.curr = 0;
      progress.total = 0;
      Response response =
          await Backend.getFileAttributeAsync(remoteFilePath, recursion: true);
      if (response.statusCode != 200) {
        sendPort.send([taskId, TransStatus.failed, response.statusMessage]);
        return;
      }
      Map result = response.data;
      if (result["code"] != 0) {
        sendPort.send([taskId, TransStatus.failed, result["message"]]);
        return;
      }
      progress.total = result["data"]["entry"]["size"];
      await downloadDirectory(remoteFileEntry, remoteFilePath, localFilePath,
          sendPort, taskId, progress);
      // TDOO: 处理部分下载失败的情况
      sendPort.send([
        taskId,
        TransStatus.succeed,
        {"code": 0, "message": "success"}
      ]);
    } else {
      return Backend.downloadFile(remoteFilePath, localFilePath, (curr, total) {
        sendPort.send([taskId, TransStatus.running, curr, total]);
      }, (result) {
        sendPort.send([taskId, TransStatus.succeed, result]);
      }, (ex, method, url) {
        sendPort.send([taskId, TransStatus.failed, ex.toString(), method, url]);
      });
    }
  }

  static Future<void> downloadDirectory(
      FileEntry remoteFileEntry,
      String remoteFilePath,
      String localFilePath,
      SendPort sendPort,
      String taskId,
      TransProgress progress) async {
    progress.currFile = remoteFilePath;
    Response response = await Backend.getFolderAsync(remoteFilePath);
    if (response.statusCode != 200) {
      progress.results[remoteFilePath] = {
        "code": response.statusCode,
        "message": response.statusMessage
      };
      return;
    }
    Map result = response.data;
    if (result["code"] != 0) {
      progress.results[remoteFilePath] = result;
      return;
    }
    Directory localDir = Directory(localFilePath);
    if (!localDir.existsSync()) {
      localDir.createSync(recursive: true);
    }
    List<dynamic> files = result["files"];
    for (var file in files) {
      FileEntry fileEntry = FileEntry();
      fileEntry.fromJson(file);
      if (fileEntry.isDir) {
        await downloadDirectory(
            fileEntry,
            joinPath([remoteFilePath, fileEntry.name]),
            p.join(localFilePath, fileEntry.name),
            sendPort,
            taskId,
            progress);
      } else {
        progress.currFile = remoteFilePath;
        await Backend.downloadFile(joinPath([remoteFilePath, fileEntry.name]),
            p.join(localFilePath, fileEntry.name), (curr, total) {
          sendPort.send([
            taskId,
            TransStatus.running,
            progress.curr + curr,
            progress.total
          ]);
        }, (result) {
          File file = File(p.join(localFilePath, fileEntry.name));
          progress.curr += file.lengthSync();
          progress.results[remoteFilePath] = result;
        }, (ex, method, url) {
          progress.results[remoteFilePath] = {
            "code": -500,
            "message": ex.toString(),
            "method": method,
            "url": url
          };
        });
      }
    }
    // TODO:支持修改目录的最后修改时间
    /*
    Directory dir = Directory(localFilePath);
    dir.setLastModifiedSync(remoteFileEntry.modifiedAt);
    */
  }

  static Future<void> uploadThread(List message) async {
    SendPort sendPort = message[0];
    Global.backendURL = message[1];
    Global.token = message[2];
    Global.sessionId = message[3];
    String taskId = message[4];
    String localFilePath = message[5];
    String remoteFilePath = message[6];
    String urlUpload = message[7];
    Map<String, dynamic>? params = message[8];

    FileSystemEntityType fileType = FileSystemEntity.typeSync(localFilePath);
    bool res = false;
    TransProgress progress = TransProgress();
    progress.curr = 0;
    if (fileType == FileSystemEntityType.directory) {
      // 如果是目录，遍历目录下的文件
      Directory directory = Directory(localFilePath);
      // 统计目录下的文件大小
      directory.listSync(recursive: true).forEach((entity) {
        if (entity is File) {
          progress.total += entity.lengthSync();
        }
      });
      res = await onUploadDirectory(directory, progress, taskId, sendPort,
          params!, localFilePath, remoteFilePath, urlUpload);
    } else if (fileType == FileSystemEntityType.file) {
      File file = File(localFilePath);
      progress.total = file.lengthSync();
      res = await onUploadFile(file, progress, taskId, sendPort, params!,
          localFilePath, remoteFilePath, urlUpload);
    } else {
      sendPort.send([
        taskId,
        TransStatus.failed,
        "CreateUploadFileTask failed!Not support file type: ${fileType.toString()}",
        "CreateUploadFileTask",
        ""
      ]);
      return;
    }

    if (res) {
      Map result = {};
      result["code"] = 0;
      result["message"] = "success";
      sendPort.send([taskId, TransStatus.succeed, result]);
    } else {
      sendPort.send([
        taskId,
        TransStatus.failed,
        "upload failed!${progress.result["code"]}: ${progress.result["message"]}",
        "UploadChunk",
        ""
      ]);
    }
  }

  static Future<bool> onUploadDirectory(
      Directory directory,
      TransProgress progress,
      String taskId,
      SendPort sendPort,
      Map<String, dynamic> params,
      String localFilePath,
      String remoteFilePath,
      String urlUpload) async {
    progress.currFile = localFilePath;
    Map result = {};
    Response response = await Backend.createFolderAsync(remoteFilePath);
    if (response.statusCode != 200) {
      result["code"] = response.statusCode;
      result["message"] = response.statusMessage;
      progress.result = result;
      return false;
    }
    result = response.data;
    if (result["code"] != 0) {
      return false;
    }
    List<FileSystemEntity> files = directory.listSync();
    for (var file in files) {
      bool res;
      if (file is Directory) {
        res = await onUploadDirectory(
            file,
            progress,
            taskId,
            sendPort,
            params,
            file.path,
            joinPath([remoteFilePath, p.basename(file.path)]),
            urlUpload);
        continue;
      } else if (file is File) {
        res = await onUploadFile(
            file,
            progress,
            taskId,
            sendPort,
            params,
            file.path,
            joinPath([remoteFilePath, p.basename(file.path)]),
            urlUpload);
      } else {
        continue;
      }
      if (!res) {
        // TODO：记录失败文件的日志。
      }
    }
    return true;
  }

  static Future<bool> onUploadFile(
      File file,
      TransProgress progress,
      String taskId,
      SendPort sendPort,
      Map<String, dynamic> params,
      String localFilePath,
      String remoteFilePath,
      String urlUpload) async {
    progress.currFile = localFilePath;
    final int fileSize = file.lengthSync();
    Response response;
    if (fileSize == 0) {
      response = await Backend.createFileAsync(
          dirName(remoteFilePath), baseName(remoteFilePath));
      if (response.statusCode != 200) {
        progress.result["code"] = response.statusCode;
        progress.result["message"] = response.statusMessage;
        return false;
      }
      progress.result = response.data;
      if (progress.result["code"] != 0) {
        return false;
      }
      return true;
    }
    response = await Backend.createUploadFileTask(
        urlUpload, {"path": dirName(remoteFilePath)}, localFilePath);
    if (response.statusCode != 200) {
      progress.result["code"] = response.statusCode;
      progress.result["message"] = response.statusMessage;
      return false;
    }
    progress.result = response.data;
    if (progress.result["code"] != 0) {
      return false;
    }
    int chunkSize = 1024 * 1024 * 10;
    bool failed = false;
    var reader = file.openSync();
    int position = 0;
    final String uploadTaskId = progress.result["data"]["upload_task_id"];
    while (fileSize > position && !failed) {
      int readSize = chunkSize;
      if (fileSize - position < readSize) {
        readSize = fileSize - position;
      }
      Uint8List bytes = reader.readSync(readSize);
      Response response = await Backend.uploadFileChunk(
          uploadTaskId, bytes, position, (finish, total) {
        if (failed) {
          return;
        }
        sendPort.send([
          taskId,
          TransStatus.running,
          progress.curr + finish,
          progress.total
        ]);
      });
      if (response.statusCode != 200) {
        failed = true;
        reader.closeSync();
        progress.result["code"] = response.statusCode;
        progress.result["message"] = response.statusMessage;
        return false;
      }
      progress.result = response.data;
      if (progress.result["code"] != 0) {
        failed = true;
        reader.closeSync();
        return false;
      }
      position += bytes.length;
      progress.curr += bytes.length;
    }
    reader.closeSync();
    return true;
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
