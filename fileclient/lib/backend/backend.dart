import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../event.dart';
import '../global.dart';
import 'dio_util.dart';

class Backend {
  static Future<Response> _doUPLOADChunk(String page, Uint8List chunk,
      Map<String, dynamic>? param, HttpProgressCallback onSendProgress) async {
    String url = '${Global.backendURL}$page';

    if (param != null) {
      String urlParam = '';
      for (var k in param.keys) {
        if (param[k].toString().isEmpty) {
          continue;
        }
        if (urlParam.isNotEmpty) {
          urlParam += "&";
        }
        urlParam += "$k=${param[k]}";
      }
      if (urlParam.isNotEmpty) {
        url += "?$urlParam";
      }
    }

    try {
      Dio dio = DioUtil.create();
      Response response = await dio.put(
        url,
        data: chunk,
        onSendProgress: onSendProgress,
        options: Options(
            headers: DioUtil.getHeaders(ext: {
              "Content-Type": "application/octet-stream",
              "Content-Length": chunk.length.toString(),
            }),
            contentType: 'application/octet-stream'),
      );
      return response;
    } catch (ex) {
      return Response(
          data: json.encode({"code": -1, "message": ex.toString()}),
          statusCode: 500,
          statusMessage: ex.toString(),
          requestOptions: RequestOptions(path: url));
    }
  }

  static Future<void> _doUPLOAD(
      String page,
      String filePath,
      HttpProgressCallback onSendProgress,
      HttpSucceedCallback onSucceed,
      HttpFailedCallback onFailed,
      Map<String, dynamic>? param) async {
    String url = '${Global.backendURL}$page';

    if (param != null) {
      String urlParam = '';
      for (var k in param.keys) {
        if (param[k].toString().isEmpty) {
          continue;
        }
        if (urlParam.isNotEmpty) {
          urlParam += "&";
        }
        urlParam += "$k=${param[k]}";
      }
      if (urlParam.isNotEmpty) {
        url += "?$urlParam";
      }
    }

    try {
      Global.logger?.d("_doUPLOAD url:$url");
      Dio dio = DioUtil.create();
      var response = await dio.post(url,
          data: FormData.fromMap({
            "path": filePath,
            "file": await MultipartFile.fromFile(
              filePath,
              contentType: DioMediaType('application', 'octet-stream'),
            ),
          }),
          onSendProgress: onSendProgress,
          options: Options(headers: DioUtil.getHeaders()));

      if (response.statusCode == HttpStatus.ok) {
        onSucceed(response.data);
      } else {
        onFailed(
            Exception(
                "Response ${response.statusCode}: ${response.statusMessage}"),
            "POST",
            url);
      }
    } catch (ex) {
      onFailed(ex, "POST", url);
    }
  }

  static Future<void> doLogin(
      bool rememberPassword,
      String serverURL,
      String username,
      String password,
      HttpSucceedCallback onSucceed,
      HttpFailedCallback onFailed) async {
    Global.logger?.i("doLogin serverURL:$serverURL username:$username");
    Map<String, dynamic> body = {
      "username": username,
      "password": password,
    };
    String url = "$serverURL/api/login";
    try {
      Dio dio = DioUtil.create();
      Response<String> response = await dio.post(url,
          data: json.encode(body),
          options: Options(headers: DioUtil.getHeaders()));

      if (response.statusCode != HttpStatus.ok) {
        onFailed(Exception("login failed!statusCode=${response.statusCode}"),
            "POST", url);
        return;
      }
      Map result = json.decode(response.data.toString());
      if (result['code'] != 0) {
        onFailed(
            Exception("login failed!${result['code']}:${result['message']}"),
            "",
            url);
        return;
      }
      if (password.isNotEmpty) {
        if (rememberPassword) {
          Global.password = password;
        } else {
          Global.password = "";
        }
      }
      Global.backendURL = serverURL;
      Global.username = username;
      Global.sessionId = result['data']['session_id'];
      Global.token = result['data']['user_token'];
      Global.userInfo.fromJson(result['data']["user"]);
      Global.userInfo.initSetting(result["data"]["settings"]);
      Global.save();
      onSucceed(result);
      return;
    } catch (ex) {
      Global.logger?.e("POST $url failed!ex:$ex");
      onFailed(ex, "POST", url);
    }
  }

  static Future<void> getFileAttribute(String path,
      HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) async {
    return DioUtil.doGET("/api/attribute", onSucceed, onFailed,
        {"path": path, "recursion": "0", "with_data": "1"});
  }

  static Future<Response> getFileAttributeAsync(String path,
      {bool recursion = false}) async {
    return DioUtil.doGETAsync("/api/attribute",
        {"path": path, "recursion": recursion ? "1" : "0", "with_data": "1"});
  }

  static Future<void> getFolder(
      String path, HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) {
    return DioUtil.doGET("/api/file", onSucceed, onFailed, {"path": path});
  }

  static Future<Response> getFolderAsync(String path) {
    return DioUtil.doGETAsync("/api/file", {"path": path});
  }

  static Future<void> deleteFile(
      String path, HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) {
    return DioUtil.doDELETE("/api/file", onSucceed, onFailed, {"path": path});
  }

  static Future<Response> deleteFileAsync(String path) {
    return DioUtil.doDELETEAsync("/api/file", {"path": path});
  }

  static Future<void> createFolder(
      String path, HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) {
    return DioUtil.doPOST(
        "/api/folder", {}, onSucceed, onFailed, {"path": path});
  }

  static Future<Response> createFolderAsync(String path) {
    return DioUtil.doPOSTAsync("/api/folder", {}, {"path": path});
  }

  static Future<void> downloadFile(
      String remoteFilePath,
      String localFilePath,
      HttpProgressCallback onReceiveProgress,
      HttpSucceedCallback onSucceed,
      HttpFailedCallback onFailed) async {
    return DioUtil.doDOWNLOAD("/api/file", localFilePath, onReceiveProgress,
        onSucceed, onFailed, {"path": remoteFilePath});
  }

  static Future<void> getFileContent(String remoteFilePath,
      HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) async {
    return DioUtil.doGET(
        "/api/file/content", onSucceed, onFailed, {"path": remoteFilePath});
  }

  static Future<Response> readFileAsync(
      String remoteFilePath, int offset, int len) async {
    return DioUtil.doGETAsync("/api/file/data",
        {"path": remoteFilePath, "offset": offset, "len": len});
  }

  static Future<Response> writeFileAsync(
      String remoteFilePath, int offset, Uint8List data) async {
    return DioUtil.doPUTDataAsync(
        "/api/file/data", data, {"path": remoteFilePath, "offset": offset});
  }

  static Future<Response> createDownloadPackageAsync(
      String fileType, String remoteFilePath, String localFilePath) {
    return DioUtil.doPOSTAsync(
        "/api/pkg", {}, {"path": remoteFilePath, "ext": fileType});
  }

  static Future<Response> queryDownloadPackageStatusAsync(String pid) {
    return DioUtil.doPUTAsync("/api/pkg", {}, {"pid": pid});
  }

  static Future<void> getDownloadPackage(
      String pid,
      String localFilePath,
      HttpProgressCallback onProgress,
      HttpSucceedCallback onSucceed,
      HttpFailedCallback onFailed) {
    return DioUtil.doDOWNLOAD("/api/pkg", localFilePath, (count, total) {
      onProgress(count, total);
    }, (result) {
      onSucceed(result);
    }, onFailed, {"pid": pid});
  }

  static Future<void> downloadPackage(
      String fileType,
      String remoteFilePath,
      String localFilePath,
      DownloadPackageCallback onProgress,
      HttpSucceedCallback onSucceed,
      HttpFailedCallback onFailed) {
    return DioUtil.doPOST("/api/pkg", {}, (result) {
      if (result["code"] != 0) {
        onFailed(
            Exception(
                "download package failed!code=${result["code"]}, message=${result["message"]}"),
            "",
            "");
        return;
      }
      String pid = result["pid"];
      Timer.periodic(const Duration(seconds: 1), (timer) {
        DioUtil.doPUT("/api/pkg", {}, (result) {
          if (result["code"] != 0) {
            timer.cancel();
            onFailed(
                Exception(
                    "download package failed!code=${result["code"]}, message=${result["message"]}"),
                "",
                "");
            return;
          }
          PackageInformation packageInformation =
              PackageInformation(result["data"]);
          onProgress(true, packageInformation.finishSize,
              packageInformation.totalSize, packageInformation);
          if (!result["data"]["finished"]) {
            return;
          }
          timer.cancel();
          DioUtil.doDOWNLOAD("/api/pkg", localFilePath, (count, total) {
            onProgress(false, count, total, null);
          }, (result) {
            onSucceed(result);
          }, onFailed, {"pid": pid});
        }, onFailed, {"pid": pid});
      });
    }, onFailed, {"path": remoteFilePath, "ext": fileType});
  }

  static Future<void> uploadFile(
      String remoteFolderPath,
      String localFilePath,
      HttpProgressCallback onReceiveProgress,
      HttpSucceedCallback onSucceed,
      HttpFailedCallback onFailed) {
    // 支持上传文件的属性
    return _doUPLOAD("/api/file", localFilePath, onReceiveProgress, onSucceed,
        onFailed, {"path": remoteFolderPath});
  }

  static Future<void> renameFile(String path, String newName,
      HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) {
    return DioUtil.doPUT("/api/file", {}, onSucceed, onFailed,
        {"path": path, "name": newName, "action": "rename"});
  }

  static Future<Response> renameFileAsync(String path, String newName) {
    return DioUtil.doPUTAsync(
        "/api/file", {}, {"path": path, "name": newName, "action": "rename"});
  }

  static Future<void> copyFile(String path, String destPath,
      HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) {
    return DioUtil.doPUT("/api/file", {}, onSucceed, onFailed,
        {"path": path, "dest": destPath, "action": "copy"});
  }

  static Future<void> moveFile(String path, String destPath,
      HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) {
    return DioUtil.doPUT("/api/file", {}, onSucceed, onFailed,
        {"path": path, "dest": destPath, "action": "move"});
  }

  static Future<void> createFile(String path, String name,
      HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) {
    return DioUtil.doPUT("/api/file", {}, onSucceed, onFailed,
        {"path": path, "name": name, "action": "create"});
  }

  static Future<Response> createFileAsync(String path, String name) {
    return DioUtil.doPUTAsync(
        "/api/file", {}, {"path": path, "name": name, "action": "create"});
  }

  static Future<void> getUsers(
      HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) {
    return DioUtil.doGET("/api/users", onSucceed, onFailed, null);
  }

  static Future<void> getServerInfo(HttpSucceedCallback onSucceed,
      HttpFailedCallback onFailed, bool withDynamic, String interval) {
    return DioUtil.doGET("/api/system", onSucceed, onFailed, {
      "with_dynamic": withDynamic ? 1 : 0,
      "interval": interval,
    });
  }

  static Future<void> getServerDiskInfo(HttpSucceedCallback onSucceed,
      HttpFailedCallback onFailed) {
    return DioUtil.doGET("/api/system/disk", onSucceed, onFailed, {});
  }

  static Future<void> getServerCpuInfo(HttpSucceedCallback onSucceed,
      HttpFailedCallback onFailed) {
    return DioUtil.doGET("/api/system/cpu", onSucceed, onFailed, {});
  }

  static Future<void> getServerMemoryInfo(HttpSucceedCallback onSucceed,
      HttpFailedCallback onFailed) {
    return DioUtil.doGET("/api/system/memory", onSucceed, onFailed, {});
  }

  static Future<void> getServerNetworkInfo(HttpSucceedCallback onSucceed,
      HttpFailedCallback onFailed) {
    return DioUtil.doGET("/api/system/net", onSucceed, onFailed, {});
  }

  static Future<void> deleteUser(UserInfo userInfo,
      HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) {
    return DioUtil.doDELETE(
        "/api/user", onSucceed, onFailed, {"user_id": userInfo.id});
  }

  static Future<void> createUser(UserInfo userInfo,
      HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) {
    Map<String, dynamic> body = {
      "name": userInfo.name,
      "password": userInfo.password,
      "email": userInfo.email,
      "root_dir": userInfo.rootDir,
      "is_admin": userInfo.isAdmin,
      "enabled": userInfo.enabled,
      "show_dot_files": userInfo.showDotFiles,
    };
    return DioUtil.doPOST("/api/user", body, onSucceed, onFailed, null);
  }

  static Future<void> updateUser(UserInfo userInfo,
      HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) {
    Map<String, dynamic> body = {
      "id": userInfo.id,
      "name": userInfo.name,
      "password": userInfo.password,
      "email": userInfo.email,
      "root_dir": userInfo.rootDir,
      "is_admin": userInfo.isAdmin,
      "enabled": userInfo.enabled,
      "show_dot_files": userInfo.showDotFiles,
    };
    return DioUtil.doPUT("/api/user", body, onSucceed, onFailed, null);
  }

  static Future<void> getSharedList(
      HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) {
    return DioUtil.doGET("/api/shareds", onSucceed, onFailed, null);
  }

  static Future<void> deleteShared(
      String sid, HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) {
    return DioUtil.doDELETE("/api/shared", onSucceed, onFailed, {"sid": sid});
  }

  static Future<void> createShared(SharedEntry sharedEntry,
      HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) {
    Map<String, dynamic> body = {
      "name": sharedEntry.name,
      "code": sharedEntry.code,
      "can_download": sharedEntry.canDownload,
      "can_upload": sharedEntry.canUpload,
      "max_count": sharedEntry.maxCount,
      "max_upload_size": sharedEntry.maxUploadSize,
      "time_limited": sharedEntry.timeLimited,
      "path": sharedEntry.path,
    };
    return DioUtil.doPOST("/api/shared", body, onSucceed, onFailed, null);
  }

  static Future<void> getSharedBaseInfo(String sid, String code,
      HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) {
    return DioUtil.doGET(
        "/api/shared", onSucceed, onFailed, {"sid": sid, "code": code});
  }

  static Future<void> getSharedFiles(String sid, String code, String path,
      HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) {
    return DioUtil.doGET("/api/shared/files", onSucceed, onFailed,
        {"sid": sid, "code": code, "path": path});
  }

  static Future<void> downloadSharedPackage(
      String sid,
      String code,
      String ext,
      String srcPath,
      String savePath,
      DownloadPackageCallback onProgress,
      HttpSucceedCallback onSucceed,
      HttpFailedCallback onFailed) async {
    // 查询构建下载包进度成功。
    // 如果没有完成，继续查询；
    // 如果已经完成，下载包
    void queryPkgSucceed(result, timer, pid) {
      if (result["code"] != 0) {
        timer.cancel();
        onFailed(
            Exception(
                "download package failed!code=${result["code"]}, message=${result["message"]}"),
            "",
            "");
        return;
      }
      PackageInformation packageInformation =
          PackageInformation(result["data"]);
      onProgress(true, packageInformation.finishSize,
          packageInformation.totalSize, packageInformation);
      if (!result["data"]["finished"]) {
        return;
      }
      timer.cancel();
      // 下载包
      DioUtil.doDOWNLOAD("/api/shared/pkg", savePath, (count, total) {
        onProgress(false, count, total, null);
      }, (result) {
        onSucceed(result);
      }, onFailed, {"sid": sid, "code": code, "pid": pid});
    }

    // 查询构建下载包进度
    queryPkg(timer, pid) {
      DioUtil.doPUT(
          "/api/shared/pkg",
          {},
          (result) => queryPkgSucceed(result, timer, pid),
          onFailed,
          {"sid": sid, "code": code, "pid": pid});
    }

    // 创建下载包成功，查询构建下载包进度
    pkgSucceed(result) {
      if (result["code"] != 0) {
        onFailed(
            Exception(
                "download package failed!code=${result["code"]}, message=${result["message"]}"),
            "",
            "");
        return;
      }
      String pid = result["pid"];
      Timer.periodic(const Duration(seconds: 3), (timer) {
        queryPkg(timer, pid);
      });
    }

    // 创建下载包
    return DioUtil.doPOST("/api/shared/pkg", {}, pkgSucceed, onFailed,
        {"sid": sid, "code": code, "ext": ext, "path": srcPath});
  }

  static Future<void> downloadSharedFile(
      String sid,
      String code,
      String srcFile,
      String savePath,
      HttpProgressCallback onReceiveProgress,
      HttpSucceedCallback onSucceed,
      HttpFailedCallback onFailed) async {
    return DioUtil.doDOWNLOAD("/api/shared/file", savePath, (count, total) {
      onReceiveProgress(count, total);
    }, (result) {
      onSucceed(result);
    }, onFailed, {"sid": sid, "code": code, "path": srcFile});
  }

  static Future<void> uploadSharedFile(
      String sid,
      String code,
      String filePath,
      String destPath,
      HttpProgressCallback onReceiveProgress,
      HttpSucceedCallback onSucceed,
      HttpFailedCallback onFailed) {
    return _doUPLOAD("/api/shared/file", filePath, onReceiveProgress, onSucceed,
        onFailed, {"sid": sid, "code": code, "path": destPath});
  }

  static Future<void> getFavorites(
      HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) {
    return DioUtil.doGET("/api/favorites", onSucceed, onFailed, null);
  }

  static Future<void> createFavorites(String name, String path,
      HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) {
    return DioUtil.doPOST("/api/favorites", {"path": path, "name": name},
        onSucceed, onFailed, {});
  }

  static Future<void> deleteFavorites(
      int id, HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) {
    return DioUtil.doDELETE("/api/favorites", onSucceed, onFailed, {"id": id});
  }

  static Future<void> getSharedHistory(
      String sid, HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) {
    return DioUtil.doGET(
        "/api/shared/history", onSucceed, onFailed, {"sid": sid});
  }

  static Future<void> getVersion(
      HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) {
    return DioUtil.doGET("/api/version", onSucceed, onFailed, null);
  }

  static Future<Response> getVersionAsync() {
    return DioUtil.doGETAsync("/api/version", null);
  }

  static Future<Response> createUploadFileTask(
      String url, Map<String, dynamic> param, String filePath) async {
    // 读取文件的属性
    File file = File(filePath);
    DateFormat formatter = DateFormat("yyyy-MM-dd HH:mm:ss");
    FileStat stat = file.statSync();
    // 支持上传文件的属性
    return DioUtil.doPOSTAsync(
        url,
        {
          "host": "linux",
          "name": p.basename(filePath),
          "is_dir": false,
          "file_mode": stat.mode,
          "size": stat.size,
          "created_at": formatter.format(stat.modified),
          "modified_at": formatter.format(stat.modified),
          "accessed_at": formatter.format(stat.accessed),
        },
        param);
  }

  static Future<Response> uploadFileChunk(String uploadTaskId, Uint8List chunk,
      int postion, HttpProgressCallback onSendProgress) async {
    return _doUPLOADChunk("/api/file/upload", chunk,
        {"upload_task_id": uploadTaskId, "position": postion}, onSendProgress);
  }

  static Future<void> changeUserSetting(Map<String, dynamic> setting,
      HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) {
    return DioUtil.doPOST(
        "/api/user/setting", setting, onSucceed, onFailed, {});
  }

  static Future<Response> checkin(String url) {
    Dio dio = DioUtil.create();
    return dio.put(url);
  }

  static Future<void> getUserHistory(
      int userId, HttpSucceedCallback onSucceed, HttpFailedCallback onFailed) {
    return DioUtil.doGET(
        "/api/user/history", onSucceed, onFailed, {"user_id": userId});
  }
}
