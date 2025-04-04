import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart';
import '../event.dart';
import '../icons/filetype2.dart';
import 'files_toolbar.dart';

class ClearIntent extends Intent {}

class IntentPasteSelected extends Intent {}

class IntentSelectedAll extends Intent {}

class IntentClearScreen extends Intent {}

class IntentPaste extends Intent {}

class IntentCopy extends Intent {}

List getXtermToolbarItems(int pageID) {
  var items = [
    {
      "icon": Icons.copy,
      "onPressed": () =>
          EventBusSingleton.instance.fire(EventXtermToolbar(pageID, "copy")),
      "name": "复制",
      "show_mode": ToolbarItemShowMode.any,
      "show_in_menu": true,
      "always_in_menu": false,
      "hotkey": "Shift+Del",
      "hostkey_data": Uint8List.fromList([27, 91, 51, 59, 50, 126])
    },
    {
      "icon": Icons.paste,
      "onPressed": () =>
          EventBusSingleton.instance.fire(EventXtermToolbar(pageID, "paste")),
      "name": "粘贴",
      "show_mode": ToolbarItemShowMode.any,
      "show_in_menu": true,
      "always_in_menu": false,
      "hotkey": "Shift+Ins",
      "hostkey_data": Uint8List.fromList([27, 91, 50, 59, 50, 126])
    },
    {
      "icon": Icons.paste,
      "onPressed": () =>
          EventBusSingleton.instance.fire(EventXtermToolbar(pageID, "paste_selected")),
      "name": "粘贴选定文本",
      "show_mode": ToolbarItemShowMode.any,
      "show_in_menu": true,
      "hotkey": "Ctrl+Shift+X",
      "always_in_menu": false,
      "key_set": LogicalKeySet(LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift, LogicalKeyboardKey.keyX),
      "intent_type": IntentPasteSelected,
      "intent_object": IntentPasteSelected(),
    },
    {
      "icon": Icons.select_all,
      "onPressed": () =>
          EventBusSingleton.instance.fire(EventXtermToolbar(pageID, "selected_all")),
      "name": "全选",
      "show_mode": ToolbarItemShowMode.any,
      "show_in_menu": true,
      "always_in_menu": false,
      "hotkey": "Ctrl+Shift+A",
      "key_set": LogicalKeySet(LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift, LogicalKeyboardKey.keyA),
      "intent_type": IntentSelectedAll,
      "intent_object": IntentSelectedAll(),
    },
    {
      "icon": Ionicons.refresh,
      "onPressed": () =>
          EventBusSingleton.instance.fire(EventXtermToolbar(pageID, "clear")),
      "name": "清屏",
      "show_mode": ToolbarItemShowMode.any,
      "show_in_menu": true,
      "always_in_menu": false,
      "hotkey": "Ctrl+L",
      "key_set":
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyL),
      "intent_type": IntentClearScreen,
      "intent_object": IntentClearScreen(),
    },
    {
      "icon": Icons.text_increase,
      "onPressed": () =>
          EventBusSingleton.instance.fire(EventXtermToolbar(pageID, "text_increase")),
      "name": "字体变大",
      "show_mode": ToolbarItemShowMode.any,
      "show_in_menu": true,
      "always_in_menu": true,
    },
    {
      "icon": Icons.text_decrease,
      "onPressed": () =>
          EventBusSingleton.instance.fire(EventXtermToolbar(pageID, "text_decrease")),
      "name": "字体变小",
      "show_mode": ToolbarItemShowMode.any,
      "show_in_menu": true,
      "always_in_menu": true,
    },
  ];
  if (!kIsWeb) {
    if (Platform.isAndroid || Platform.isIOS) {
      items.addAll([
        {
          "icon": FileType2.cn,
          "onPressed": () => EventBusSingleton.instance
              .fire(EventXtermToolbar(pageID, "chinese_keybroad")),
          "name": "中文键盘",
          "show_mode": ToolbarItemShowMode.any,
          "show_in_menu": true,
          "always_in_menu": false,
        },
        {
          "icon": FileType2.en,
          "onPressed": () => EventBusSingleton.instance
              .fire(EventXtermToolbar(pageID, "english_keybroad")),
          "name": "英文键盘",
          "show_mode": ToolbarItemShowMode.any,
          "show_in_menu": true,
          "always_in_menu": false,
        },
      ]);
    }
  }
  items.addAll([
    {
      "show_mode": ToolbarItemShowMode.any,
      "show_in_menu": true,
      "always_in_menu": true,
    },
    {
      "icon": Icons.close,
      "onPressed": () =>
          EventBusSingleton.instance.fire(EventXtermToolbar(pageID, "close")),
      "name": "退出终端",
      "show_mode": ToolbarItemShowMode.any,
      "show_in_menu": true,
      "always_in_menu": true,
    },
  ]);
  return items;
}

class XtermToolbar extends StatefulWidget {
  const XtermToolbar(
      {required this.pageID, super.key, this.isLandScape = true});
  final int pageID;
  final bool isLandScape;
  @override
  State<XtermToolbar> createState() => _XtermToolbarState();
}

class _XtermToolbarState extends State<XtermToolbar> {
  String _title = "";
  late StreamSubscription<EventXtermChanged> listenEventXtermChanged;
  @override
  void dispose() {
    super.dispose();
    listenEventXtermChanged.cancel();
  }

  @override
  void initState() {
    super.initState();
    listenEventXtermChanged =
        EventBusSingleton.instance.on<EventXtermChanged>().listen((event) {
      if (event.pageID != widget.pageID) {
        return;
      }
      if (event.action != XtermAction.changedTitle) {
        return;
      }
      _title = event.value;
      setState(() {});
    });
  }

  bool isShow(ToolbarItemShowMode mode) {
    switch (mode) {
      case ToolbarItemShowMode.any:
        break;
      default:
        return false;
    }
    return true;
  }

  List<Widget> buildLandScapeToolbarWidgets() {
    List<Widget> result = [Text(_title)];
    for (Map item in getXtermToolbarItems(widget.pageID)) {
      if (item["always_in_menu"] || !isShow(item["show_mode"])) {
        continue;
      }
      if (item["icon"] == null) {
        result.add(const SizedBox(
          width: 16,
          child: VerticalDivider(
            thickness: 1.0,
            indent: 12,
            endIndent: 12,
          ),
        ));
        continue;
      }
      result.add(IconButton(
        onPressed: item["onPressed"],
        icon: Icon(item["icon"],
            color: item.containsKey("enabled") && item["enabled"]
                ? Colors.orange
                : null),
        tooltip: item["name"],
      ));
    }
    result.add(PopupMenuButton(
      tooltip: "更多",
      itemBuilder: (context) => buildPopupMenuItems(context, "always_in_menu"),
      onSelected: onSelectPopupMenuItem,
    ));
    return result;
  }

  List<Widget> buildPortraitToolbarWidgets() {
    List<Widget> result = [Text(_title)];
    for (Map item in getXtermToolbarItems(widget.pageID)) {
      if (item["show_in_menu"] || !isShow(item["show_mode"])) {
        continue;
      }
      if (item["icon"] == null) {
        result.add(const SizedBox(
          width: 16,
          child: VerticalDivider(
            thickness: 1.0,
            indent: 12,
            endIndent: 12,
          ),
        ));
        continue;
      }
      result.add(IconButton(
        onPressed: item["onPressed"],
        icon: Icon(item["icon"],
            color: item.containsKey("enabled") && item["enabled"]
                ? Colors.orange
                : null),
        tooltip: item["name"],
      ));
    }
    result.add(PopupMenuButton(
      tooltip: "更多",
      itemBuilder: (context) => buildPopupMenuItems(context, "show_in_menu"),
      onSelected: onSelectPopupMenuItem,
    ));
    result.add(SizedBox(
      width: 16,
    ));
    return result;
  }

  void onSelectPopupMenuItem(String value) {
    for (Map item in getXtermToolbarItems(widget.pageID)) {
      if (item.toString() == value) {
        item["onPressed"]();
        break;
      }
    }
  }

  List<PopupMenuItem<String>> buildPopupMenuItems(
      BuildContext context, String key) {
    List<PopupMenuItem<String>> result = [];
    for (Map item in getXtermToolbarItems(widget.pageID)) {
      if (!item[key] || !isShow(item["show_mode"])) {
        continue;
      }
      if (item.containsKey("menu")) {}
      if (item["icon"] == null) {
        result.add(const PopupMenuItem<String>(
          enabled: false,
          height: 4,
          padding: EdgeInsets.all(0),
          child: Divider(),
        ));
        continue;
      }
      Color? color = item.containsKey("enabled") && item["enabled"]
          ? Colors.orange
          : Theme.of(context).iconTheme.color;
      result.add(PopupMenuItem<String>(
        value: item.toString(),
        child: Row(
          children: [
            Icon(item["icon"], color: color),
            const SizedBox(width: 8),
            Text(item["name"]),
            const SizedBox(width: 8),
            item.containsKey("enabled") && item["enabled"]
                ? const Icon(
                    Icons.check,
                    color: Colors.orange,
                    size: 16,
                  )
                : const SizedBox(),
          ],
        ),
      ));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
        children: widget.isLandScape
            ? buildLandScapeToolbarWidgets()
            : buildPortraitToolbarWidgets());
  }
}
