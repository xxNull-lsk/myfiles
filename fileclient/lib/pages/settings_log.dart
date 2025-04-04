import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:logger/logger.dart';

import '../global.dart';

class SettingsLogPage extends StatefulWidget {
  const SettingsLogPage({super.key});

  @override
  State<SettingsLogPage> createState() => _SettingsLogPageState();
}

class _SettingsLogPageState extends State<SettingsLogPage> {
  final TextEditingController _textEditingController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), getLogs);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      getLogs();
    });
  }

  void moveCursorToLastLine() {
    // 获取当前文本长度
    int length = _textEditingController.text.length;

    // 计算光标应该移动到的位置（最后一行）
    int lastRowPosition =
        length - (_textEditingController.text.lastIndexOf('\n') + 1);

    // 更新光标位置
    _textEditingController.selection = TextSelection.fromPosition(
      TextPosition(offset: lastRowPosition),
    );
    Future.delayed(Duration(milliseconds: 100), () {
      if (!mounted) {
        return;
      }
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });

    int count = 0;
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) {
        return false;
      }
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      if (count >= 5) {
        return false;
      }
      count++;
      return true;
    });
  }

  void getLogs() {
    if (!mounted) {
      return;
    }
    if (Global.logFile.isEmpty) {
      return;
    }

    File f = File(Global.logFile);
    if (!f.existsSync()) {
      return;
    }
    String log = f.readAsStringSync();
    if (log.length > 4096) {
      log = log.substring(log.length - 4096);
    }
    if (_textEditingController.text == log) {
      return;
    }
    _textEditingController.text = log;
    moveCursorToLastLine();
    setState(() {});
  }

  Future<void> onClearLogs() async {
    await Global.logger?.close();
    File f = File(Global.logFile);
    f.deleteSync();
    Global.initLog();
    setState(() {
      _textEditingController.text = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
      child: ListView(
        controller: _scrollController,
        children: [
          Container(
            padding: const EdgeInsets.only(left: 16),
            child: TextField(
              style: const TextStyle(fontFamily: "Mono"),
              readOnly: true,
              maxLines: null,
              controller: _textEditingController,
              decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8))),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                const Text("日志"),
                IconButton(
                    onPressed: getLogs, icon: const Icon(Ionicons.refresh)),
                const Spacer(),
                IconButton(
                    onPressed: onClearLogs, icon: const Icon(Ionicons.trash))
              ],
            ),
          ),
          SwitchListTile(
              value: Global.logLevel == Level.debug,
              title: const Text("显示详细日志"),
              onChanged: (value) {
                setState(() {
                  if (value) {
                    Global.logLevel = Level.debug;
                  } else {
                    Global.logLevel = Level.info;
                  }
                  Global.save();
                  Global.initLog();
                });
              }),
        ],
      ),
    );
  }
}
