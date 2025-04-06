import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fileclient/util.dart';

import '../backend/backend.dart';
import '../file_types.dart';
import '../global.dart';
import 'base.dart';

class ServerFileSystem extends BaseFileSystem {
  @override
  Future<bool> createFolder(String filepath, {int mode = 0}) async {
    Response response = await Backend.createFolderAsync(filepath);
    if (response.statusCode != HttpStatus.ok) {
      return false;
    }
    var result = json.decode(response.data.toString());
    if (result["code"] != 0) {
      Global.logger
          ?.e("create folder failed. ${result["code"]}: ${result["message"]}");
      return false;
    }
    Global.logger?.i("create folder succeed. filepath: $filepath, mode: $mode");
    return true;
  }

  @override
  Future<BaseFile?> createFile(String filepath, {int mode = 0}) async {
    Response response =
        await Backend.createFileAsync(dirName(filepath), baseName(filepath));
    if (response.statusCode != HttpStatus.ok) {
      return null;
    }
    var result = json.decode(response.data.toString());
    if (result["code"] != 0) {
      Global.logger
          ?.e("create file failed. ${result["code"]}: ${result["message"]}");
      return null;
    }
    Global.logger?.i("create file succeed. filepath: $filepath, mode: $mode");
    return ServerFile(filepath);
  }

  @override
  Future<FileAttributes?> getFileAttri(String filepath) async {
    Response response = await Backend.getFileAttributeAsync(filepath);
    if (response.statusCode != HttpStatus.ok) {
      return null;
    }
    var result = response.data;
    if (result["code"] != 0) {
      Global.logger
          ?.e("get file attri failed. ${result["code"]}: ${result["message"]}");
      return null;
    }
    FileAttributes attributes = FileAttributes();
    attributes.fromJson(result["data"]);
    return attributes;
  }

  @override
  Future<BaseDirectory?> openDir(String filepath) async {
    Response response = await Backend.getFolderAsync(filepath);
    if (response.statusCode != HttpStatus.ok) {
      Global.logger?.e(
          "get folder failed. ${response.statusCode} ${response.statusMessage}");
      return null;
    }
    Map data = json.decode(response.data.toString());
    if (data["code"] != 0) {
      Global.logger
          ?.e("get folder failed. ${data["code"]}: ${data["message"]}");
      return null;
    }
    return ServerDirectory(data);
  }

  @override
  Future<BaseFile?> openFile(String filepath) async {
    return ServerFile(filepath);
  }

  @override
  Future<bool> remove(String filepath) async {
    Response response = await Backend.deleteFileAsync(filepath);
    if (response.statusCode != HttpStatus.ok) {
      return false;
    }
    return true;
  }

  @override
  Future<bool> rename(String from, String to) async {
    Response response = await Backend.renameFileAsync(from, to);
    if (response.statusCode != HttpStatus.ok) {
      return false;
    }
    return true;
  }
}

class ServerDirectory extends BaseDirectory {
  final List<FileAttributes> _files = [];
  ServerDirectory(Map data) {
    data["files"].forEach((element) {
      FileAttributes attributes = FileAttributes();
      attributes.fromJson(element);
      _files.add(attributes);
    });
  }
  @override
  int count() {
    return _files.length;
  }

  @override
  List<FileAttributes> get(int index, int count) {
    return _files.sublist(index, count);
  }
}

class ServerFile extends BaseFile {
  final String _filepath;
  ServerFile(this._filepath);
  @override
  Future<void> close() async {
    return;
  }

  @override
  Future<void> flush() async {
    return;
  }

  @override
  Future<Uint8List?> read(int offset, int len) async {
    Response response = await Backend.readFileAsync(_filepath, offset, len);
    if (response.statusCode != HttpStatus.ok) {
      Global.logger?.e(
          "read file failed. filepath:$_filepath offset:$offset len:$len ${response.statusCode}: ${response.statusMessage}");
      return null;
    }
    Global.logger
        ?.d("read file succeed. filepath:$_filepath offset:$offset len:$len");
    return response.data;
  }

  @override
  Future<bool> write(int offset, Uint8List data) async {
    Response response = await Backend.writeFileAsync(_filepath, offset, data);
    if (response.statusCode != HttpStatus.ok) {
      return false;
    }
    var result = json.decode(response.data.toString());
    if (result["code"] != 0) {
      Global.logger?.e(
          "write file failed. filepath:$_filepath offset:$offset ${result["code"]}: ${result["message"]}");
      return false;
    }
    Global.logger?.d("write file succeed. filepath:$_filepath offset:$offset");
    return true;
  }
}
