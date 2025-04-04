import 'dart:convert' as convert;
import 'dart:math';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';

import 'global.dart';

String generateSha512(String data) {
  var content = const convert.Utf8Encoder().convert(data);
  var digest = sha512.convert(content);
  return hex.encode(digest.bytes);
}

String removeRightChars(String str, String chars) {
  int index = str.length - 1;
  while (index >= 0 && chars.contains(str[index])) {
    index--;
  }
  return str.substring(0, index + 1);
}

String formatBytes(int bytes, int decimals, {bool fixWidth = false}) {
  if (bytes == 0) return '0 B';
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
  final i = (log(bytes) / log(1024)).floor();
  final value = bytes / pow(1024, i);
  String decimalValue = value.toStringAsFixed(decimals);
  if (!fixWidth) {
    decimalValue = removeRightChars(decimalValue, '0');
    decimalValue = removeRightChars(decimalValue, '.');
  }
  return '$decimalValue ${suffixes[i]}';
}

String formatDuration(Duration d) {
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
  return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
}

String humanizerDatetime(DateTime dt, {bool withRemain = false}) {
  Duration d = DateTime.now().difference(dt);
  if (d.inMinutes < 1) {
    if (withRemain) {
      return "${d.inSeconds}秒前";
    }
    return "刚刚";
  }
  if (d.inMinutes < 60) {
    if (withRemain) {
      Duration seconds = d - Duration(minutes: d.inMinutes);
      return "${d.inMinutes}分钟 ${seconds.inSeconds}秒前";
    }
    return "${d.inMinutes}分钟前";
  }
  if (d.inHours < 24) {
    if (withRemain) {
      Duration minutes = d - Duration(hours: d.inHours);
      Duration seconds = minutes - Duration(minutes: minutes.inMinutes);
      return "${d.inHours}小时 ${minutes.inMinutes}分钟 ${seconds.inSeconds}秒前";
    }
    return "${d.inHours}小时前";
  }
  if (d.inDays < 7) {
    if (withRemain) {
      return "${d.inDays}天 ${formatDuration(d - Duration(days: d.inDays))}前";
    }
    return "${d.inDays}天前";
  }
  DateFormat dateFormat = DateFormat("yyyy-MM-dd HH:mm:ss");
  return dateFormat.format(dt);
}

String generateRandomString(int length) {
  const String charset =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  final Random random = Random();
  String result = '';

  for (var i = 0; i < length; i++) {
    result += charset[random.nextInt(charset.length)];
  }

  return result;
}

String baseName(String path, {String sep = '/'}) {
  // 去除末尾的分隔符
  while (path.endsWith(sep)) {
    path = path.substring(0, path.length - 1);
  }

  if (path.isEmpty || path == sep) {
    return sep;
  }
  int index = path.lastIndexOf(sep);
  if (index == -1) {
    return path;
  }
  return path.substring(index + 1);
}

String dirName(String path, {String sep = '/'}) {
  // 去除末尾的分隔符
  while (path.endsWith(sep)) {
    path = path.substring(0, path.length - 1);
  }

  if (path.isEmpty || path == sep) {
    return sep;
  }
  int index = path.lastIndexOf(sep);
  if (index == -1) {
    return sep;
  }
  String name = path.substring(0, index);
  if (name.isEmpty) {
    return sep;
  }
  return name;
}

String joinPath(List<String> pathItems, {String sep = '/'}) {
  String result = "";
  for (var item in pathItems) {
    if (item.isEmpty || item == sep || item == ".") {
      continue;
    }
    if (result.endsWith(sep)) {
      result += item;
      continue;
    } else if (item.startsWith(sep)) {
      result += item;
      continue;
    } else {
      result += "$sep$item";
    }
  }
  return result;
}

void onFailed(dynamic ex, String method, String url) {
  Global.logger?.e(ex);
  if (ex is DioException) {
    if (ex.response == null) {
      toastification.show(
          type: ToastificationType.error,
          title: Text("请求失败 $url"),
          pauseOnHover: true,
          description: Text(ex.toString()),
          autoCloseDuration: const Duration(seconds: 5));
      Get.offAllNamed("/login");
      return;
    }
    if (ex.response?.statusCode == 401) {
      toastification.show(
        type: ToastificationType.error,
        title: const Text("登录已过期，请重新登录"),
        autoCloseDuration: const Duration(seconds: 3),
      );
      Get.offAllNamed("/login");
      return;
    }
    if (ex.response != null) {
      toastification.show(
          type: ToastificationType.error,
          title: Text(ex.response!.statusMessage.toString()),
          pauseOnHover: true,
          description: Text(ex.response!.data.toString()),
          autoCloseDuration: const Duration(seconds: 5));
      return;
    }
  }
  toastification.show(
      title: Text(ex.toString()),
      pauseOnHover: true,
      description: Text(ex.toString()),
      autoCloseDuration: const Duration(seconds: 5));
}

bool isEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}