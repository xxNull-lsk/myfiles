import 'dart:convert';
import 'dart:html' as html;

import 'package:fileclient/global.dart';

import '../../backend/dio_util.dart';

Future<bool> onUpload(
    int pageID,
    String url,
    Map<String, dynamic> param,
    HttpProgressCallback onReceiveProgress,
    HttpSucceedCallback onSucceed,
    HttpFailedCallback onFailed) async {
  html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
  uploadInput.multiple = false; // 是否允许选择多文件
  uploadInput.draggable = true;
  uploadInput.click();

  uploadInput.onChange.listen((event) async {
    // 选择完成
    html.File? file = uploadInput.files?.first;
    if (file == null) {
      return;
    }

    Global.logger?.i('上传${file.name}...');
    html.FormData formData = html.FormData();
    formData.appendBlob('file', file.slice(), file.name);
    //上传文件到服务器
    var request = html.HttpRequest();
    String params = "";
    for (var item in param.entries) {
      if (params.isEmpty) {
        params += "?";
      }
      if (params.isNotEmpty) {
        params += "&";
      }
      params += "${item.key}=${item.value}";
    }
    var url = "${Global.backendURL}/api/file$params";
    request.open('POST', url);
    for (var item in DioUtil.getHeaders().entries) {
      request.setRequestHeader(item.key, item.value);
    }
    request.send(formData);
    request.onProgress.listen((event) {
      onReceiveProgress(event.loaded ?? 0, event.total ?? 1);
    });
    request.onError.listen((event) {
      onFailed(event, 'upload', '');
    });
    request.onLoadEnd.listen((event) {
      Global.logger?.i('上传${file.name}结果：${request.responseText}');
      //因为上传结果返回的是response字符串，所以使用JsonDecoder转成Json格式，进行数据解析
      var response = const JsonDecoder().convert(request.response);
      onSucceed(response);
    });
  });
  return true;
}
