import 'dart:io';
import 'dart:typed_data';
import 'package:fileclient/global.dart';
import 'package:path/path.dart' as p;
import 'package:fileclient/filesystem/base.dart';

import '../file_types.dart';

class LocalFileSystem extends BaseFileSystem {
  @override
  Future<bool> createFolder(String filepath, {int mode = 0}) async {
    Directory dir = Directory(filepath);
    try {
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
    } catch (ex) {
      return false;
    }
    return true;
  }

  @override
  Future<BaseFile?> createFile(String filepath, {int mode = 0}) async {
    File f = File(filepath);
    if (!f.existsSync()) {
      f.createSync(recursive: true, exclusive: true);
    }
    return openFile(filepath);
  }

  @override
  Future<FileAttributes?> getFileAttri(String filepath) async {
    FileSystemEntity entity = FileSystemEntity.isFileSync(filepath)
        ? File(filepath)
        : Directory(filepath);
    if (!entity.existsSync()) {
      return null;
    }
    FileStat stat = entity.statSync();
    FileAttributes attributes = FileAttributes();
    attributes.fromState(p.basename(filepath), stat);
    return attributes;
  }

  @override
  Future<bool> remove(String filepath) async {
    try {
      FileSystemEntity entity = FileSystemEntity.isDirectorySync(filepath)
          ? Directory(filepath)
          : File(filepath);
      entity.deleteSync(recursive: true);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> rename(String from, String to) async {
    try {
      FileSystemEntity entity =
          FileSystemEntity.isDirectorySync(from) ? Directory(from) : File(from);
      entity.renameSync(to);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<BaseDirectory?> openDir(String filepath) async {
    if (!FileSystemEntity.isDirectorySync(filepath)) {
      return null;
    }
    return LocalDirectory(filepath);
  }

  @override
  Future<BaseFile?> openFile(String filepath) async {
    if (!FileSystemEntity.isFileSync(filepath)) {
      return null;
    }
    return LocalFile(filepath);
  }
}

class LocalDirectory extends BaseDirectory {
  final List<FileAttributes> _files = [];
  LocalDirectory(String dirPath) {
    Directory dir = Directory(dirPath);
    dir.listSync().every((element) {
      LocalFileSystem()
          .getFileAttri(element.path)
          .then((value) => _files.add(value!));
      return true;
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

class LocalFile extends BaseFile {
  RandomAccessFile? _randomAccessFile;
  LocalFile(String filePath) {
    _randomAccessFile = File(filePath).openSync(mode: FileMode.write);
  }
  @override
  Future<void> close() async {
    return _randomAccessFile?.close();
  }

  @override
  Future<void> flush() async {
    await _randomAccessFile?.flush();
  }

  @override
  Future<Uint8List?> read(int offset, int len) async {
    _randomAccessFile?.setPositionSync(offset);
    return _randomAccessFile?.read(len);
  }

  @override
  Future<bool> write(int offset, Uint8List data)async  {
    try {
      _randomAccessFile?.setPositionSync(offset);
      _randomAccessFile?.writeFromSync(data.toList());
      return true;
    } catch (e) {
      Global.logger?.e(e);
      return false;
    }
  }
}
