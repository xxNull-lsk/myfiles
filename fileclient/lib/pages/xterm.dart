import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:contextmenu/contextmenu.dart';
import 'package:fileclient/dialog/message_dialog.dart';
import 'package:fileclient/event.dart';
import 'package:fileclient/global.dart';
import 'package:fileclient/pages/keep_alive_wrapper.dart';
import 'package:fileclient/pages/mode/ssh.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:toastification/toastification.dart';
import 'package:xterm/xterm.dart';

import '../dialog/input_dialog.dart';
import '../util.dart';
import 'base_page.dart';
import 'ssh_file_drawer.dart';
import 'util/virtual_keyborad.dart';
import 'xterm_toolbar.dart';

import 'util/desktop_check.dart' if (dart.library.html) 'util/web_check.dart';

class XtermPage extends BasePage {
  const XtermPage(
      {required this.pageID,
      required this.cfg,
      required this.xtermFilePath,
      super.key});

  final int pageID;
  final XtermConfig cfg;
  final String xtermFilePath;

  @override
  int getPageID() => pageID;

  @override
  IconData getIcon() {
    return Icons.terminal;
  }

  @override
  String getTitle() {
    return Global.ssh[pageID]?.getTitle() ?? "终端";
  }

  @override
  PageType getPageType() {
    return PageType.xterm;
  }

  @override
  State<XtermPage> createState() => _XtermPageState();

  @override
  Widget getToolbar(bool isLandScape) {
    return XtermToolbar(pageID: pageID, isLandScape: isLandScape);
  }

  @override
  Widget? getSidebar() {
    if (kIsWeb) {
      return null;
    }
    return KeepAliveWrapper(
        child: SshFileDrawer(
      pageID: pageID,
      key: GlobalKey(),
    ));
  }
}

class _XtermPageState extends State<XtermPage> {
  late Terminal _terminal = Terminal(inputHandler: keyboard);
  final keyboard = VirtualKeyboard(defaultInputHandler);
  late StreamSubscription<EventXterm> listenEventXterm;
  late StreamSubscription<EventXtermToolbar> listenEventXtermToolbar;
  final TerminalController _terminalController = TerminalController();
  StreamSubscription? _subscriptionSshEvent;

  TextInputType _keyboardType = TextInputType.text;
  double _fontSize = 16;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    listenEventXterm =
        EventBusSingleton.instance.on<EventXterm>().listen((event) {
      if (event.pageID != widget.pageID) {
        return;
      }
      connect(event.cfg, event.xtermFilePath);
      setState(() {});
    });
    listenEventXtermToolbar =
        EventBusSingleton.instance.on<EventXtermToolbar>().listen((event) {
      if (!mounted) {
        return;
      }
      switch (event.name) {
        case "clear":
          _terminal.buffer.clear();
          _terminal.buffer.setCursor(0, 0);
          setState(() {});
          _terminal.keyInput(TerminalKey.enter);
          break;
        case "copy":
          if (_terminalController.selection == null) {
            toastification.show(
              title: const Text("复制失败"),
              description: const Text("请先选中要复制的内容"),
              type: ToastificationType.error,
              autoCloseDuration: const Duration(seconds: 2),
            );
            return;
          }
          String text = _terminal.buffer.getText(_terminalController.selection);
          Clipboard.setData(ClipboardData(text: text));
          break;
        case "paste":
          Clipboard.getData("text/plain").then((value) {
            if (value == null || value.text == null) {
              toastification.show(
                title: const Text("粘贴失败"),
                description: const Text("剪贴板为空"),
                type: ToastificationType.error,
                autoCloseDuration: const Duration(seconds: 2),
              );
              return;
            }
            _terminal.textInput(value.text!);
          });
          break;
        case "paste_selected":
          if (_terminalController.selection == null) {
            return;
          }
          String text = _terminal.buffer.getText(_terminalController.selection);
          _terminal.textInput(text);
          break;
        case "selected_all":
          {
            _terminalController.setSelection(
                _terminal.buffer.createAnchor(0, 0),
                _terminal.buffer.createAnchor(0, _terminal.buffer.height - 1));
            setState(() {});
          }
        case "chinese_keybroad":
          _keyboardType = TextInputType.emailAddress;
          setState(() {});
          break;
        case "english_keybroad":
          _keyboardType = TextInputType.text;
          setState(() {});
          break;
        case "text_increase":
          if (_fontSize > 128) {
            return;
          }
          _fontSize++;
          setState(() {});
          break;
        case "text_decrease":
          if (_fontSize < 6) {
            return;
          }
          _fontSize--;
          setState(() {});
          break;
        case "close":
          _isClosed = true;
          Global.ssh[widget.pageID]?.close();
          Global.ssh.remove(widget.pageID);
          Global.filesKey.currentState?.closePage(widget.pageID);
          break;
      }
    });
  }

  bool _isClosed = true;
  void initTerminal(Ssh ssh) {
    _isClosed = false;
    _subscriptionSshEvent?.cancel();
    _subscriptionSshEvent = ssh.event().listen((event) {
      switch (event.type) {
        case SshEventType.stdout:
        case SshEventType.stderr:
          _terminal.write(event.message);
          break;
        case SshEventType.error:
          toastification.show(
            title: const Text("错误"),
            description: Text(event.message),
            type: ToastificationType.error,
            autoCloseDuration: const Duration(seconds: 2),
          );
          EventBusSingleton.instance
              .fire(EventXtermToolbar(widget.pageID, "close"));
          break;
        case SshEventType.reconnect:
          if (!mounted || _isClosed) {
            return;
          }
          _isClosed = true;
          if (Global.currentPageID != widget.pageID) {
            return;
          }
          showMessageDialog(context, "提示", event.message).then(
            (value) {
              if (value != MessageDialogResult.ok) {
                EventBusSingleton.instance
                    .fire(EventXtermToolbar(widget.pageID, "close"));
                return;
              }
              _isClosed = false;
              _terminal.buffer.clear();
              _terminal.buffer.setCursor(0, 0);
              ssh.connect(
                viewWidth: _terminal.viewWidth,
                viewHeight: _terminal.viewHeight,
              );
            },
          );
          break;
        case SshEventType.connected:
          _isClosed = false;
          _terminal.buffer.clear();
          _terminal.buffer.setCursor(0, 0);
          break;
        case SshEventType.changedCurrentPath:
          EventBusSingleton.instance.fire(EventXtermChanged(
              widget.pageID, XtermAction.changedPath, event.message));
          break;
        case SshEventType.closed:
          _isClosed = true;
          Global.ssh[widget.pageID]?.close();
          Global.ssh.remove(widget.pageID);
          Global.filesKey.currentState?.closePage(widget.pageID);
          break;
      }
      ssh.refreshCurrentPath();
    });

    _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      ssh.resize(width, height);
    };
    _terminal.onOutput = (txt) {
      var data = utf8.encode(txt);
      for (Map item in getXtermToolbarItems(widget.pageID)) {
        if (item["hostkey_data"] == null) {
          continue;
        }
        if (isEqual(item["hostkey_data"], data)) {
          item["onPressed"]();
          return;
        }
      }
      ssh.write(data);
    };

    _terminal.onTitleChange = (title) {
      EventBusSingleton.instance.fire(
          EventXtermChanged(widget.pageID, XtermAction.changedTitle, title));

      Global.ssh[widget.pageID]?.refreshCurrentPath();
    };
  }

  @override
  void didChangeDependencies() {
    if (Global.ssh[widget.pageID] != null) {
      _terminal = Global.ssh[widget.pageID]!.terminal;
      initTerminal(Global.ssh[widget.pageID]!);
      if (_isClosed) {
        Global.ssh[widget.pageID]?.connect(
          viewWidth: _terminal.viewWidth,
          viewHeight: _terminal.viewHeight,
        );
      }
    } else {
      connect(widget.cfg, widget.xtermFilePath);
    }
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant XtermPage oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    listenEventXterm.cancel();
    Global.ssh[widget.pageID]?.terminal = _terminal;
    _subscriptionSshEvent?.cancel();
    _subscriptionSshEvent = null;
    _focusNode.dispose();
    super.dispose();
  }

  Future<String> onPasswordRequest() async {
    dynamic xtermConfig = Global.ssh[widget.pageID]?.xtermConfig;
    if (xtermConfig == null || xtermConfig!.password.isEmpty) {
      String? result = await showInputDialog(
        context,
        title: "请输入密码",
        dataType: InputDataType.password,
      );
      return result ?? "";
    }
    return xtermConfig!.password;
  }

  void connect(XtermConfig cfg, String xtermFilePath) async {
    if (cfg.host.isEmpty || cfg.port == 0 || cfg.username.isEmpty) {
      toastification.show(
        title: const Text("连接失败"),
        description: const Text("请先配置连接信息"),
        type: ToastificationType.error,
        autoCloseDuration: const Duration(seconds: 2),
      );
      EventBusSingleton.instance
          .fire(EventXtermToolbar(widget.pageID, "close"));
      return;
    }

    try {
      _terminal.buffer.clear();
      _terminal.buffer.setCursor(0, 0);
      if (mounted) {
        _terminal.write('Connecting ${cfg.host}:${cfg.port}...\r\n');
      }
      Ssh ssh = Ssh(widget.pageID, xtermFilePath, cfg,
          onPasswordRequest: onPasswordRequest);
      Global.ssh[widget.pageID] = ssh;
      initTerminal(ssh);

      ssh.connect(
        viewWidth: _terminal.viewWidth,
        viewHeight: _terminal.viewHeight,
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        ssh.resize(_terminal.viewWidth, _terminal.viewHeight);
      });

      _focusNode.requestFocus();
    } catch (e) {
      toastification.show(
        title: const Text("连接失败"),
        description: Text("$e"),
        type: ToastificationType.error,
        autoCloseDuration: const Duration(seconds: 2),
      );
      return;
    }
  }

  void onKeyInput(String key, TerminalKey value) {
    switch (value) {
      case TerminalKey.nonConvert:
        {
          _terminal.textInput(key);
          break;
        }
      default:
        {
          _terminal.keyInput(value);
          break;
        }
    }
  }

  Widget buildShortcutManager({required Widget child}) {
    if (!kIsWeb && Platform.isAndroid && Platform.isIOS) {
      return child;
    }
    Map<LogicalKeySet, Intent> shortcuts = {};
    Map<Type, Action<Intent>> actions = {};
    for (Map item in getXtermToolbarItems(widget.pageID)) {
      if (item["key_set"] == null) {
        continue;
      }

      LogicalKeySet keySet = item["key_set"];
      shortcuts[keySet] = item["intent_object"];
      actions[item["intent_type"]] =
          CallbackAction<Intent>(onInvoke: (Intent intent) {
        item["onPressed"]();
        return null;
      });
    }
    return Shortcuts.manager(
        manager: ShortcutManager(shortcuts: shortcuts),
        child: Actions(actions: actions, child: child));
  }

  ContextMenuArea buildTerminalPopupMenu({required Widget child}) {
    return ContextMenuArea(
      child: buildShortcutManager(child: child),
      builder: (BuildContext context) {
        List<Widget> popupMenuEntries = [];

        for (Map item in getXtermToolbarItems(widget.pageID)) {
          if (item["icon"] == null) {
            popupMenuEntries.add(const Divider());
            continue;
          }
          popupMenuEntries.add(ListTile(
            leading: Icon(item["icon"]),
            title: Text(item["name"]),
            trailing: Text(item["hotkey"] ?? ""),
            onTap: () {
              Navigator.of(context).pop();
              item["onPressed"]();
            },
          ));
        }
        return popupMenuEntries;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool bShowKeyboard = isMobile();
    return CupertinoPageScaffold(
      child: buildTerminalPopupMenu(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TerminalView(
                focusNode: _focusNode,
                _terminal,
                onKeyEvent: (FocusNode node, KeyEvent event) {
                  if (!kIsWeb ||
                      event is! KeyUpEvent ||
                      event.logicalKey != LogicalKeyboardKey.space) {
                    return KeyEventResult.ignored;
                  }
                  _terminal.textInput(' ');
                  return KeyEventResult.handled;
                },
                keyboardType: _keyboardType,
                controller: _terminalController,
                padding: const EdgeInsets.all(8),
                textStyle: TerminalStyle(
                  fontFamily: "NotoSansMono",
                  fontSize: _fontSize,
                ),
              ),
            ),
            Visibility(
              visible: bShowKeyboard,
              child: VirtualKeyboardView(
                keyboard,
                callback: onKeyInput,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
