import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

import '../event.dart';
import '../global.dart';

typedef HttpProgressCallback = void Function(int count, int total);
typedef HttpSucceedCallback = void Function(Map result);
typedef HttpFailedCallback = void Function(
    dynamic ex, String method, String url);
typedef AsyncHttpSucceedCallback = Future<void> Function(Map result);
typedef AsyncHttpFailedCallback = Future<void> Function(
    dynamic ex, String method, String url);
typedef DownloadPackageCallback = void Function(
    bool isPacking, int count, int total, PackageInformation? packageInfo);

class DioUtil {
  static Dio create() {
    Dio dio = Dio();
    // 允许自签名证书
    if (!kIsWeb && Global.allowSelfCertificate) {
      if (dio.httpClientAdapter is IOHttpClientAdapter) {
        (dio.httpClientAdapter as IOHttpClientAdapter).validateCertificate =
            (X509Certificate? certificate, String host, int port) {
          Global.logger?.t("validateCertificate. host=$host port=$port");
          return true;
        };
      }
      if (dio.httpClientAdapter is DefaultHttpClientAdapter) {
        (dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate =
            (client) {
          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) {
            Global.logger?.t("badCertificateCallback. host=$host port=$port");
            return true;
          };
          return client;
        };
      }
    }
    return dio;
  }

  static Map<String, String> getHeaders({Map<String, String>? ext}) {
    Map<String, String> headers = {};
    if (kIsWeb) {
      headers['app-name'] = "web";
    } else {
      headers['app-name'] = Platform.operatingSystem;
    }
    if (Global.token.isNotEmpty) {
      headers["user-token"] = Global.token;
      headers["session-id"] = Global.sessionId;
    }
    if (ext != null) {
      headers.addAll(ext);
    }
    return headers;
  }

  static Future<void> doPUT(
      String page,
      Map<String, dynamic> body,
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

    Map<String, dynamic> headers = getHeaders();

    try {
      dynamic data = json.encode(body);
      headers['Content-Length'] = data.length.toString();

      Dio dio = create();
      Response<String> response =
          await dio.put(url, data: data, options: Options(headers: headers));

      var result = json.decode(response.data.toString());
      if (response.statusCode == HttpStatus.ok) {
        onSucceed(result);
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

  static Future<Response> doPUTAsync(String page, Map<String, dynamic> body,
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

    Map<String, dynamic> headers = getHeaders();

    try {
      dynamic data = json.encode(body);
      headers['Content-Length'] = data.length.toString();

      Dio dio = create();
      return dio.put(url, data: data, options: Options(headers: headers));
    } catch (ex) {
      return Response(
          data: json.encode({"code": -1, "message": ex.toString()}),
          statusCode: 500,
          statusMessage: ex.toString(),
          requestOptions: RequestOptions(path: url));
    }
  }


  static Future<Response> doPUTDataAsync(String page, Uint8List data,
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

    Map<String, dynamic> headers = getHeaders();

    try {
      headers['Content-Length'] = data.length.toString();

      Dio dio = create();
      return dio.put(url, data: data, options: Options(headers: headers));
    } catch (ex) {
      return Response(
          data: json.encode({"code": -1, "message": ex.toString()}),
          statusCode: 500,
          statusMessage: ex.toString(),
          requestOptions: RequestOptions(path: url));
    }
  }

  static Future<void> doPOST(
      String page,
      Map<String, dynamic> body,
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

    Map<String, dynamic> headers = getHeaders();

    try {
      dynamic data = json.encode(body);
      headers['Content-Length'] = data.length.toString();
      Dio dio = create();
      Response<String> response =
          await dio.post(url, data: data, options: Options(headers: headers));

      var result = json.decode(response.data.toString());
      if (response.statusCode == HttpStatus.ok) {
        onSucceed(result);
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

  static Future<Response> doPOSTAsync(String page, Map<String, dynamic> body,
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

    Map<String, dynamic> headers = getHeaders();

    try {
      dynamic data = json.encode(body);
      headers['Content-Length'] = data.length.toString();
      Dio dio = create();
      return dio.post(url, data: data, options: Options(headers: headers));
    } catch (ex) {
      return Response(
          data: json.encode({"code": -1, "message": ex.toString()}),
          statusCode: 500,
          statusMessage: ex.toString(),
          requestOptions: RequestOptions(path: url));
    }
  }

  static Future<void> doGET(String page, HttpSucceedCallback onSucceed,
      HttpFailedCallback onFailed, Map<String, dynamic>? param) async {
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
      Global.logger?.d("_doGET url:$url");
      Dio dio = create();
      Response<String> response =
          await dio.get(url, options: Options(headers: getHeaders()));

      var result = json.decode(response.data.toString());
      if (response.statusCode == HttpStatus.ok) {
        onSucceed(result);
      } else {
        onFailed(
            Exception(
                "Response ${response.statusCode}: ${response.statusMessage}"),
            "GET",
            url);
      }
    } catch (ex) {
      onFailed(ex, "GET", url);
    }
  }

  static Future<Response> doGETAsync(
      String page, Map<String, dynamic>? param) async {
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
      Global.logger?.d("_doGET url:$url");
      Dio dio = create();
      return dio.get(url, options: Options(headers: getHeaders()));
    } catch (ex) {
      return Response(
          data: json.encode({"code": -1, "message": ex.toString()}),
          statusCode: 500,
          statusMessage: ex.toString(),
          requestOptions: RequestOptions(path: url));
    }
  }

  static Future<void> doDELETE(String page, HttpSucceedCallback onSucceed,
      HttpFailedCallback onFailed, Map<String, dynamic>? param) async {
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
      Global.logger?.d("_doDELETE url:$url");
      Dio dio = create();
      Response<String> response =
          await dio.delete(url, options: Options(headers: getHeaders()));

      var result = json.decode(response.data.toString());
      if (response.statusCode == HttpStatus.ok) {
        onSucceed(result);
      } else {
        onFailed(
            Exception(
                "Response ${response.statusCode}: ${response.statusMessage}"),
            "DELETE",
            url);
      }
    } catch (ex) {
      onFailed(ex, "DELETE", url);
    }
  }

  static Future<Response> doDELETEAsync(
      String page, Map<String, dynamic>? param) async {
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
      Global.logger?.d("_doDELETE url:$url");
      Dio dio = create();
      return dio.delete(url, options: Options(headers: getHeaders()));
    } catch (ex) {
      return Response(
          data: json.encode({"code": -1, "message": ex.toString()}),
          statusCode: 500,
          statusMessage: ex.toString(),
          requestOptions: RequestOptions(path: url));
    }
  }

  static Future<void> doDOWNLOAD(
      String page,
      String savePath,
      HttpProgressCallback onReceiveProgress,
      HttpSucceedCallback onSucceed,
      HttpFailedCallback onFailed,
      Map<String, dynamic>? param) async {
    String url = '${Global.backendURL}$page';

    if (kIsWeb) {
      if (param == null) {
        param = getHeaders();
      } else {
        param.addAll(getHeaders());
      }
    }

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
      Global.logger?.d("_doDOWNLOAD url:$url");
      Dio dio = create();
      if (kIsWeb) {
        html.window.open(url, '_blank');
        onSucceed({
          "code": 0,
          "message": "download success!",
          "savePath": savePath,
        });
      } else {
        var headers = getHeaders();
        Response<dynamic> response = await dio.download(url, savePath,
            onReceiveProgress: onReceiveProgress,
            options: Options(headers: headers));

        if (response.statusCode == 200) {
          onSucceed({
            "code": 0,
            "message": "download success!",
            "localFilePath": savePath,
          });
        } else {
          onFailed(Exception("download failed"), "GET", url);
        }
      }
    } catch (ex) {
      onFailed(ex, "GET", url);
    }
  }
}
