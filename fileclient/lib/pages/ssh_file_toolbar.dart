import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../event.dart';

List getSshFileToolbarItems(int pageID) {
  var items = [
    {
      "icon": Icons.arrow_upward,
      "onPressed": () =>
          EventBusSingleton.instance.fire(EventSshFileToolbar(pageID, "upward")),
      "name": "上一级目录",
      "show_in_menu": false
    },
    {
      "icon": Icons.refresh,
      "onPressed": () =>
          EventBusSingleton.instance.fire(EventSshFileToolbar(pageID,  "refresh")),
      "name": "刷新",
      "show_in_menu": false
    }
  ];

  if (!kIsWeb) {
    items.addAll([
      {
        "icon": Icons.upload,
        "onPressed": () =>
            EventBusSingleton.instance.fire(EventSshFileToolbar(pageID,  "upload")),
        "name": "上传",
        "show_in_menu": true
      },
      {
        "icon": Icons.download,
        "onPressed": () =>
            EventBusSingleton.instance.fire(EventSshFileToolbar(pageID,  "download")),
        "name": "下载",
        "show_in_menu": true
      },
      {
        "icon": Icons.delete,
        "onPressed": () =>
            EventBusSingleton.instance.fire(EventSshFileToolbar(pageID,  "delete")),
        "name": "删除",
        "show_in_menu": true
      }
    ]);
  }
  return items;
}

class SshFileToolbar extends StatefulWidget {
  const SshFileToolbar({super.key, required this.title, required this.pageID});
  final String title;
  final int pageID;
  @override
  State<SshFileToolbar> createState() => _SshFileToolbarState();
}

class _SshFileToolbarState extends State<SshFileToolbar> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  List<Widget> buildToolbarWidgets() {
    List<Widget> result = [];
    for (Map item in getSshFileToolbarItems(widget.pageID)) {
      if (item["show_in_menu"]) {
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
        padding: EdgeInsets.all(0),
        splashRadius: 16,
        onPressed: item["onPressed"],
        icon: Icon(item["icon"]),
        tooltip: item["name"],
      ));
    }
    result.add(PopupMenuButton(
      borderRadius: BorderRadius.circular(16),
      padding: EdgeInsets.all(0),
      splashRadius: 16,
      tooltip: "更多",
      itemBuilder: (context) => buildPopupMenuItems(context, "show_in_menu"),
      onSelected: onSelectPopupMenuItem,
    ));
    return result;
  }

  void onSelectPopupMenuItem(String value) {
    for (Map item in getSshFileToolbarItems(widget.pageID)) {
      if (item.toString() == value) {
        item["onPressed"]();
        break;
      }
    }
  }

  List<PopupMenuItem<String>> buildPopupMenuItems(
      BuildContext context, String key) {
    List<PopupMenuItem<String>> result = [];
    for (Map item in getSshFileToolbarItems(widget.pageID)) {
      if (!item[key]) {
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
      result.add(PopupMenuItem<String>(
        value: item.toString(),
        child: ListTile(
          leading: Icon(item["icon"]),
          title: Text(item["name"]),
        ),
      ));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          Text(
            widget.title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Spacer(),
          ...buildToolbarWidgets(),
        ]);
  }
}
