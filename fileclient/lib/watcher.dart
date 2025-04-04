import 'dart:async';
import 'dart:io';

import 'package:fileclient/event.dart';

class WatchItem {
  int pageID;
  String fileType;
  String remoteFilePath;
  bool isExist;
  DateTime lastModified;
  WatchItem(this.pageID, this.remoteFilePath, this.isExist, this.lastModified,
      this.fileType);
}

class Watcher {
  Watcher();
  Map<String, WatchItem> watchers = {};
  Timer? myTimer;
  Future<void> watch(int pageID, String localFilePath, String remoteFilePath,
      String fileType) async {
    if (watchers.keys.contains(localFilePath)) {
      return;
    }
    var localFile = File(localFilePath);
    watchers[localFilePath] = WatchItem(pageID, remoteFilePath,
        localFile.existsSync(), localFile.lastModifiedSync(), fileType);

    if (watchers.length == 1) {
      myTimer = Timer.periodic(Duration(seconds: 1), doCheck);
    }
  }

  void unwatch(String localFilePath) {
    watchers.remove(localFilePath);
    if (watchers.isEmpty && myTimer != null && myTimer!.isActive) {
      myTimer!.cancel();
    }
  }

  void doCheck(Timer timer) {
    for (var element in watchers.entries) {
      File localFile = File(element.key);
      if (element.value.isExist) {
        if (!localFile.existsSync()) {
          element.value.isExist = false;
          EventBusSingleton.instance.fire(EventWatchFileChanged(
              element.value.pageID,
              element.key,
              element.value.remoteFilePath,
              element.value.fileType,
              WatchEventType.delete));
          continue;
        }
        DateTime lastModified = localFile.lastModifiedSync();
        if (lastModified.difference(element.value.lastModified).inMilliseconds >
            0) {
          EventBusSingleton.instance.fire(EventWatchFileChanged(
              element.value.pageID,
              element.key,
              element.value.remoteFilePath,
              element.value.fileType,
              WatchEventType.modified));
          element.value.lastModified = lastModified;
        }
      } else {
        if (localFile.existsSync()) {
          EventBusSingleton.instance.fire(EventWatchFileChanged(
              element.value.pageID,
              element.key,
              element.value.remoteFilePath,
              element.value.fileType,
              WatchEventType.add));
          element.value.isExist = true;
        }
      }
    }
  }
}
