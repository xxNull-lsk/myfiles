import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import 'icons/filetype1.dart';
import 'icons/filetype2.dart';

class FileEntry {
  String name = "";
  bool isDir = false;
  int fileMode = 0;
  int size = 0;
  DateTime createdAt = DateTime.now();
  DateTime modifiedAt = DateTime.now();
  void fromJson(Map data) {
    name = data["name"];
    isDir = data["is_dir"];
    fileMode = data["file_mode"];
    size = data["size"];
    createdAt = DateTime.parse(data["created_at"]);
    modifiedAt = DateTime.parse(data["modified_at"]);
  }

  void fromState(String filename, FileStat stat) {
    name = filename;
    isDir = stat.type == FileSystemEntityType.directory;
    fileMode = stat.mode;
    size = stat.size;
    createdAt = stat.changed;
    modifiedAt = stat.modified;
  }

  Map toMap() {
    return {
      "name": name,
      "is_dir": isDir,
      "file_mode": fileMode,
      "size": size,
      "created_at": createdAt.toIso8601String(),
      "modified_at": modifiedAt.toIso8601String(),
    };
  }
}

class FileAttributes {
  FileEntry entry = FileEntry();
  int fileCount = 0;
  int dirCount = 0;
  void fromJson(Map data) {
    entry.fromJson(data["entry"]);
    fileCount = data["file_count"];
    dirCount = data["dir_count"];
  }

  void fromState(String filename, FileStat stat) {
    entry.fromState(filename, stat);
    fileCount = 0;
    dirCount = 0;
  }
}

class FileItem {
  FileItem({Map? fileEntry}) {
    if (fileEntry == null) {
      return;
    }
    FileEntry tmp = FileEntry();
    tmp.fromJson(fileEntry);
    set(tmp);
  }
  set(FileEntry fileEntry) {
    entry = fileEntry;
    if (entry.isDir) {
      icon = FileType1.folder;
    } else {
      String extName = path.extension(entry.name);
      extName = extName.toLowerCase().replaceFirst(".", "");
      for (var iconItem in FileType1Preview.iconList) {
        if (iconItem.propName == extName) {
          icon = iconItem.icon;
          break;
        }
      }
      if (icon == null) {
        for (var iconItem in FileType2Preview.iconList) {
          if (iconItem.propName == extName) {
            icon = iconItem.icon;
            break;
          }
        }
      }
      icon ??= FileType1.file;
    }
  }

  FileEntry entry = FileEntry();
  IconData? icon;
  bool selected = false;
  Function onOpen = () {};
}
