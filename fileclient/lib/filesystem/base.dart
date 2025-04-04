import 'dart:typed_data';

import '../file_types.dart';

abstract class BaseFileSystem {
  Future<bool> createFolder(String filepath, {int mode = 0});
  Future<BaseDirectory?> openDir(String filepath);

  Future<bool> rename(String from, String to);
  Future<bool> remove(String filepath);

  Future<FileAttributes?> getFileAttri(String filepath);

  Future<BaseFile?> createFile(String filepath, {int mode = 0});
  Future<BaseFile?> openFile(String filepath);
}

abstract class BaseFile {
  Future<Uint8List?> read(int offset, int len);
  Future<bool> write(int offset, Uint8List data);
  Future<void> flush();
  Future<void> close();
}

abstract class BaseDirectory {
  int count();
  List<FileAttributes> get(int index, int count);
}