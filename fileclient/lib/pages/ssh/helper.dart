import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../../event.dart';

class SftpHelper {
  static Future<void> downloadThread(List message) async {
    SendPort sendPort = message[0];
    String remoteFilePath = message[1];
    String localFilePath = message[2];
    int totalSize = message[3];
    XtermConfig cfg = message[4];

    SSHClient sshClient = SSHClient(
        await SSHSocket.connect(cfg.host, cfg.port,
            timeout: const Duration(seconds: 3)),
        username: cfg.username,
        onPasswordRequest: () => cfg.password,
        onVerifyHostKey: (type, fingerprint) => true,
        identities:
            cfg.authKey.isEmpty ? null : [...SSHKeyPair.fromPem(cfg.authKey)]);
    if (sshClient.isClosed) {
      return;
    }
    SftpClient sftp = await sshClient.sftp();
    var f = File(localFilePath).openSync(mode: FileMode.write);
    int finish = 0;
    double transPercent = 0;
    SftpFile sftpFile =
        await sftp.open(remoteFilePath, mode: SftpFileOpenMode.read);
    sftpFile.read().listen((event) async {
      f.writeFromSync(event.toList());
      finish += event.length;
      double percent;
      if (totalSize == 0) {
        percent = 0.99;
      } else {
        percent = finish / totalSize;
      }
      if (percent - transPercent > 0.01) {
        transPercent = percent;
        sendPort.send(["percent", percent]);
      }
    }).onDone(() {
      sendPort.send(["download_finish", remoteFilePath, localFilePath]);
      sftpFile.close();
      f.closeSync();
      sftp.close();
      sshClient.close();
    });
  }

  static Future<void> uploadThread(List message) async {
    SendPort sendPort = message[0];
    String remoteFilePath = message[1];
    String localFilePath = message[2];
    XtermConfig cfg = message[3];

    SSHClient sshClient = SSHClient(
        await SSHSocket.connect(cfg.host, cfg.port,
            timeout: const Duration(seconds: 3)),
        username: cfg.username,
        onPasswordRequest: () => cfg.password,
        onVerifyHostKey: (type, fingerprint) => true,
        identities:
            cfg.authKey.isEmpty ? null : [...SSHKeyPair.fromPem(cfg.authKey)]);
    if (sshClient.isClosed) {
      return;
    }
    SftpClient sftp = await sshClient.sftp();
    var f = File(localFilePath).openSync(mode: FileMode.read);
    int finishSize = 0;
    int totalSize = f.lengthSync();
    double transPercent = 0;
    SftpFile sftpFile = await sftp.open(remoteFilePath,
        mode: SftpFileOpenMode.write |
            SftpFileOpenMode.create |
            SftpFileOpenMode.truncate);

    while (true) {
      Uint8List data = await f.read(1024 * 1024);
      if (data.isEmpty) {
        break;
      }
      await sftpFile.writeBytes(data, offset: finishSize);
      finishSize += data.length;
      double percent;
      if (totalSize == 0) {
        percent = 0.99;
      } else {
        percent = finishSize / totalSize;
      }
      if (percent - transPercent > 0.01) {
        transPercent = percent;
        sendPort.send(["percent", percent]);
      }
    }

    sendPort.send(["upload_finish", remoteFilePath, localFilePath]);
    sftpFile.close();
    f.closeSync();
    sftp.close();
    sshClient.close();
  }
}
