import 'dart:async';
import 'dart:convert';

import 'package:fileclient/global.dart';
import 'package:fileclient/util.dart';
import 'package:flutter/services.dart';
import 'package:web_socket/web_socket.dart';

Future<WebSshClient> createWebSshClient(String xtermFilePath, int width, int height) async {
  Uri uri = Uri.parse(Global.backendURL);
  String scheme = uri.scheme == "https" ? "wss" : "ws";
  uri = Uri(
      scheme: scheme,
      host: uri.host,
      port: uri.port,
      path: joinPath([uri.path, "/api/xterm"]),
      queryParameters: {
        "path": xtermFilePath,
        "user-token": Global.token,
        "session-id": Global.sessionId,
        "width": width.toString(),
        "height": height.toString()
      });
  WebSocket socket = await WebSocket.connect(uri);
  return WebSshClient(socket);
}

class WebSshClient {
  Timer? timer;
  WebSocket socket;
  final _stderrController = StreamController<Uint8List>();
  final _stdoutController = StreamController<Uint8List>();
  Stream<Uint8List> get stdout => _stdoutController.stream;
  Stream<Uint8List> get stderr => _stderrController.stream;
  WebSshClient(this.socket) {
    keepalive();
    socket.events.listen((e) async {
      switch (e) {
        case TextDataReceived(text: final text):
          Map data = jsonDecode(text);
          if (data["type"] == "stdout") {
            _stdoutController.sink.add(base64Decode(data["data"]));
          } else if (data["type"] == "stderr") {
            _stderrController.sink.add(base64Decode(data["data"]));
          } else {
            Global.logger?.w("unknown data type: ${data["type"]}");
          }
        case BinaryDataReceived(data: final data):
          _stdoutController.sink.add(data);
        case CloseReceived(code: final code, reason: final reason):
          Global.logger?.w('Received Close: $code, $reason');
          timer?.cancel();
          await socket.close();
      }
    });
  }

  void write(Uint8List data) {
    var base64Data = base64Encode(data);
    socket.sendText(jsonEncode({"type": "stdin", "data": base64Data}));
  }

  void resize(int width, int height) {
    socket.sendText(jsonEncode({
      "type": "resize",
      "data": jsonEncode({"cols": width, "rows": height})
    }));
  }

  void keepalive() {
    timer = Timer.periodic(Duration(seconds: 3), (timer) {
      socket.sendText(jsonEncode({"type": "keepalive"}));
    });
  }

  void close() {
    timer?.cancel();
    socket.close();
  }
}
