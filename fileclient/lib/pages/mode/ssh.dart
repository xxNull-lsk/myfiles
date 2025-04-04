import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:dio/dio.dart';
import 'package:fileclient/global.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../backend/backend.dart';
import '../../event.dart';
import '../../util.dart';
import '../ssh/web_ssh_client.dart';

enum SshEventType {
  error,
  connected, // 连接成功
  reconnect, // 需要重新连接
  closed, // 连接关闭
  changedCurrentPath, // 当前路径改变
  stdout,
  stderr,
}

class SshEvent {
  final SshEventType type;
  final String message;
  SshEvent(this.type, this.message);
}

class Ssh {
  int pageID;
  SftpClient? sftp;
  SSHClient? sshClient;
  SSHSession? session;
  WebSshClient? webSshClient;

  String xtermFilePath;
  XtermConfig xtermConfig;

  XtermConfig? sftpConfig;
  Map<String, dynamic> _shellInfo = {};

  String sftpPath = "";
  String pagePath = "";

  dynamic terminal;

  final SSHPasswordRequestHandler? onPasswordRequest;
  Ssh(this.pageID, this.xtermFilePath, this.xtermConfig, {this.onPasswordRequest});

  dynamic _eventController = StreamController<SshEvent>();

  String getTitle() {
    if (xtermConfig.title.isNotEmpty) {
      return  "${-pageID}.终端：${xtermConfig.title}";
    }
    String title = baseName(xtermFilePath);
    return "${-pageID}.终端：${p.basenameWithoutExtension(title)}";
  }

  void close() {
    _eventController.close();
    sftpPath = "";
    pagePath = "";
    session?.close();
    sftp?.close();
    sshClient?.close();
    webSshClient?.close();
  }

  Stream<SshEvent> event() {
    _eventController = StreamController<SshEvent>();
    return _eventController.stream;
  }

  void connect({viewWidth = 0, viewHeight = 0}) async {
    if (xtermConfig.host.isEmpty ||
        xtermConfig.port == 0 ||
        xtermConfig.username.isEmpty) {
      _eventController.sink.add(SshEvent(SshEventType.error, "请先配置连接信息"));
      return;
    }
    if (kIsWeb) {
      connectWebSocket(viewWidth, viewHeight);
    } else {
      connectNormal(viewWidth, viewHeight);
    }
  }

  Future<void> connectWebSocket(int viewWidth, int viewHeight) async {
    webSshClient = await createWebSshClient(xtermFilePath, viewWidth, viewHeight);
    if (webSshClient == null) {
      _eventController.sink.add(SshEvent(SshEventType.reconnect, "连接失败"));
      return;
    }
    _eventController.sink.add(SshEvent(SshEventType.connected, "连接成功"));

    webSshClient?.stdout
        .cast<List<int>>()
        .transform(Utf8Decoder())
        .listen((data) {
      _eventController.sink.add(SshEvent(SshEventType.stdout, data));
    });

    webSshClient?.stderr
        .cast<List<int>>()
        .transform(Utf8Decoder())
        .listen((data) {
      _eventController.sink.add(SshEvent(SshEventType.stderr, data));
    });
  }

  Future<void> connectNormal(int viewWidth, int viewHeight) async {
    if (xtermConfig.checkin.isNotEmpty) {
      Response result = await Backend.checkin(xtermConfig.checkin);
      if (result.statusCode != 200) {
        _eventController.sink.add(SshEvent(SshEventType.error,
            "CheckIn 失败!${result.statusCode}:${result.statusMessage}"));
        return;
      }
    }
    _eventController.sink.add(SshEvent(SshEventType.stdout, "CheckIn 成功.\r\n"));
    try {
      sshClient = SSHClient(
          await SSHSocket.connect(xtermConfig.host, xtermConfig.port,
              timeout: const Duration(seconds: 3)),
          keepAliveInterval: const Duration(seconds: 1),
          username: xtermConfig.username,
          onPasswordRequest: onPasswordRequest,
          onVerifyHostKey: (type, fingerprint) => true,
          identities: xtermConfig.authKey.isEmpty
              ? null
              : [...SSHKeyPair.fromPem(xtermConfig.authKey)]);
    } catch (e) {
      _eventController.sink.add(SshEvent(SshEventType.stderr, "连接失败$e\r\n"));
      _eventController.sink.add(SshEvent(SshEventType.reconnect, "连接失败"));
      return;
    }
    _eventController.sink.add(SshEvent(SshEventType.connected, "连接成功"));
    session = await sshClient!.shell(
      pty: SSHPtyConfig(
        width: viewWidth,
        height: viewHeight,
      ),
    );
    session?.done.whenComplete(() {
      try {
        _eventController.sink.add(SshEvent(SshEventType.closed, "连接失败，是否重试？"));
      } catch (e) {
        Global.logger?.e("session done: $e");
      }
    });
    sshClient?.done.whenComplete(() {
      try {
        _eventController.sink
            .add(SshEvent(SshEventType.reconnect, "连接失败，是否重试？"));
      } catch (e) {
        Global.logger?.e("sshClient done: $e");
      }
    });

    session?.stdout.cast<List<int>>().transform(Utf8Decoder()).listen((data) {
      _eventController.sink.add(SshEvent(SshEventType.stdout, data));
    });

    session?.stderr.cast<List<int>>().transform(Utf8Decoder()).listen((data) {
      _eventController.sink.add(SshEvent(SshEventType.stderr, data));
    });

    sftp = await sshClient!.sftp();
    sftpConfig = XtermConfig({
      "host": xtermConfig.host,
      "port": xtermConfig.port,
      "username": xtermConfig.username,
      "password": xtermConfig.password,
      "auth_key": xtermConfig.authKey
    });

    Future<String> loadAsset() async {
      return await rootBundle.loadString('assets/get_curr_shell.sh');
    }

    loadAsset().then((shellContent) async {
      String filename = generateRandomString(6);
      sftp!
          .open("/tmp/$filename.sh",
              mode: SftpFileOpenMode.write | SftpFileOpenMode.create)
          .then((val) {
        val.writeBytes(utf8.encode(shellContent));
        val.close();

        sshClient!.run("bash /tmp/$filename.sh").then((val) {
          sftp?.remove("/tmp/$filename.sh");
          int index = val.indexOf(0x7b);
          _shellInfo = jsonDecode(utf8.decode(val.sublist(index)));
          sftpPath = _shellInfo["SSH_CWD"];
          _eventController.sink
              .add(SshEvent(SshEventType.changedCurrentPath, sftpPath));
        });
      });
    });
  }

  void refreshCurrentPath() {
    if (kIsWeb) {
      return;
    }

    if (!_shellInfo.containsKey("SSH_PID") || sshClient!.isClosed) {
      return;
    }
    try {
      sshClient!.run("readlink /proc/${_shellInfo["SSH_PID"]}/cwd").then((val) {
        String currPath = utf8.decode(val);
        currPath = currPath.trimRight();
        if (currPath == sftpPath) {
          return;
        }

        sftpPath = _shellInfo["SSH_CWD"] = currPath;
        _eventController.sink
            .add(SshEvent(SshEventType.changedCurrentPath, currPath));
      }).catchError((ex) {
        Global.logger?.e("sshClient run: $ex");
      });
    } catch (e) {
      Global.logger?.e("refreshCurrentPath: $e");
    }
  }

  void write(Uint8List data) {
    if (kIsWeb) {
      webSshClient?.write(data);
    } else {
      session?.write(data);
    }
  }

  void resize(int width, int height) {
    if (kIsWeb) {
      webSshClient?.resize(width, height);
    } else {
      session?.resizeTerminal(width, height, width, height);
    }
  }
}
