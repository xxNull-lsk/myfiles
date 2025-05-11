import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import '../event.dart';
import '../global.dart';
import '../icons/filetype1.dart';
import '../icons/filetype2.dart';

enum ToolbarItemShowMode {
  any,
  selectZero, // 选择零个
  selectOne, // 仅仅选择一个
  selectOneOrMore, // 选择一个或多个
  selectMoreThanOne, // 选择多个
}

bool isShow(ToolbarItemShowMode mode, int selectedCount) {
  switch (mode) {
    case ToolbarItemShowMode.any:
      break;
    case ToolbarItemShowMode.selectZero:
      if (selectedCount != 0) {
        return false;
      }
      break;
    case ToolbarItemShowMode.selectOne:
      if (selectedCount != 1) {
        return false;
      }
      break;
    case ToolbarItemShowMode.selectOneOrMore:
      if (selectedCount == 0) {
        return false;
      }
      break;
    case ToolbarItemShowMode.selectMoreThanOne:
      if (selectedCount <= 1) {
        return false;
      }
      break;
  }
  return true;
}

List getFileToolbarItems(int pageID) {
  return [
    {
      "icon": Icons.refresh,
      "onPressed": () =>
          EventBusSingleton.instance.fire(EventToolbar(pageID, "refresh")),
      "name": "刷新",
      "show_mode": ToolbarItemShowMode.any,
      "show_in_menu": true
    },
    {
      "icon": Icons.open_in_new,
      "onPressed": () =>
          EventBusSingleton.instance.fire(EventToolbar(pageID, "open_with")),
      "name": "打开为...",
      "show_mode": ToolbarItemShowMode.selectOne,
      "platform": [
        "android",
        "ios",
        "web",
      ],
      "show_in_menu": true
    },
    {
      "icon": Icons.send,
      "onPressed": () =>
          EventBusSingleton.instance.fire(EventToolbar(pageID, "sendto")),
      "name": "发送到...",
      "show_mode": ToolbarItemShowMode.selectOne,
      "platform": [
        "android",
        "ios",
      ],
      "show_in_menu": true
    },
    {
      "icon": Icons.share,
      "onPressed": () =>
          EventBusSingleton.instance.fire(EventToolbar(pageID, "shared")),
      "name": "分享",
      "show_mode": ToolbarItemShowMode.selectOne,
      "show_in_menu": true
    },
    {
      "icon": Icons.favorite_outline,
      "onPressed": () =>
          EventBusSingleton.instance.fire(EventToolbar(pageID, "favorite")),
      "name": "收藏",
      "show_mode": ToolbarItemShowMode.any,
      "show_in_menu": true
    },
    {
      "icon": Icons.edit,
      "onPressed": () =>
          EventBusSingleton.instance.fire(EventToolbar(pageID, "rename")),
      "name": "改名",
      "show_mode": ToolbarItemShowMode.selectOne,
      "show_in_menu": true
    },
    {
      "icon": Icons.copy,
      "onPressed": () =>
          EventBusSingleton.instance.fire(EventToolbar(pageID, "copy")),
      "name": "复制",
      "show_mode": ToolbarItemShowMode.selectOneOrMore,
      "show_in_menu": false
    },
    {
      "icon": Icons.cut,
      "onPressed": () =>
          EventBusSingleton.instance.fire(EventToolbar(pageID, "move")),
      "name": "移动",
      "show_mode": ToolbarItemShowMode.selectOneOrMore,
      "show_in_menu": false
    },
    {
      "icon": Icons.delete_outline,
      "onPressed": () =>
          EventBusSingleton.instance.fire(EventToolbar(pageID, "delete")),
      "name": "删除",
      "show_mode": ToolbarItemShowMode.selectOneOrMore,
      "show_in_menu": true
    },
    {
      "icon": Icons.add,
      "onPressed": () =>
          EventBusSingleton.instance.fire(EventToolbar(pageID, "create_file")),
      "name": "新建文件",
      "show_mode": ToolbarItemShowMode.selectZero,
      "show_in_menu": false
    },
    {
      "icon": Icons.create_new_folder_outlined,
      "onPressed": () => EventBusSingleton.instance
          .fire(EventToolbar(pageID, "create_folder")),
      "name": "新建目录",
      "show_mode": ToolbarItemShowMode.selectZero,
      "show_in_menu": false
    },
    {
      "icon": Ionicons.download_outline,
      "onPressed": () =>
          EventBusSingleton.instance.fire(EventToolbar(pageID, "download")),
      "name": "下载",
      "show_mode": ToolbarItemShowMode.selectOneOrMore,
      "show_in_menu": true,
    },
    {
      "icon": FileType1.zip,
      "name": "下载为zip压缩文件",
      "show_mode": ToolbarItemShowMode.selectOne,
      "show_in_menu": true,
      "onPressed": () =>
          EventBusSingleton.instance.fire(EventToolbar(pageID, "download.zip")),
    },
    {
      "icon": FileType1.gz,
      "name": "下载为tar.gz压缩文件",
      "show_mode": ToolbarItemShowMode.selectOne,
      "show_in_menu": true,
      "onPressed": () => EventBusSingleton.instance
          .fire(EventToolbar(pageID, "download.tar.gz")),
    },
    {
      "icon": Icons.upload_file_outlined,
      "onPressed": () =>
          EventBusSingleton.instance.fire(EventToolbar(pageID, "upload")),
      "name": "上传",
      "show_mode": ToolbarItemShowMode.any,
      "show_in_menu": true
    },
    {
      "icon": Icons.attribution,
      "onPressed": () =>
          EventBusSingleton.instance.fire(EventToolbar(pageID, "attribution")),
      "name": "属性",
      "show_mode": ToolbarItemShowMode.any,
      "show_in_menu": true
    },
    {
      "icon": Icons.sort,
      "onPressed": null,
      "name": () {
        String name = Global.filePages[pageID]!.sortBy.chineseName;
        if (Global.filePages[pageID]!.sortDesc) {
          return "$name(倒序)";
        }
        return name;
      },
      "show_mode": ToolbarItemShowMode.any,
      "show_in_menu": true,
      "children": [
        {
          "icon": FileType2.sort_asc,
          "onPressed": () => EventBusSingleton.instance
              .fire(EventToolbar(pageID, "sort_by_type")),
          "name": "类型排序",
          "show_mode": ToolbarItemShowMode.any,
          "show_in_menu": true,
        },
        {
          "icon": FileType2.sort_a_z,
          "onPressed": () => EventBusSingleton.instance
              .fire(EventToolbar(pageID, "sort_by_name")),
          "name": "名称排序",
          "show_mode": ToolbarItemShowMode.any,
          "show_in_menu": true,
        },
        {
          "icon": FileType2.sort_1_9,
          "onPressed": () => EventBusSingleton.instance
              .fire(EventToolbar(pageID, "sort_by_size")),
          "name": "大小排序",
          "show_mode": ToolbarItemShowMode.any,
          "show_in_menu": true,
        },
        {
          "icon": FileType2.sort_time_down,
          "onPressed": () => EventBusSingleton.instance
              .fire(EventToolbar(pageID, "sort_by_modified")),
          "name": "修改时间排序",
          "show_mode": ToolbarItemShowMode.any,
          "show_in_menu": true,
        },
      ]
    },
  ];
}

class FilesToolbar extends StatefulWidget {
  const FilesToolbar(
      {super.key, required this.pageID, this.isLandScape = true});
  final bool isLandScape;
  final int pageID;
  @override
  State<FilesToolbar> createState() => _FilesToolbarState();
}

class _FilesToolbarState extends State<FilesToolbar> {
  late List fileToolbarItems;
  late StreamSubscription<EventSelectFile> listenEventSelectFile;
  @override
  void dispose() {
    super.dispose();
    listenEventSelectFile.cancel();
  }

  @override
  void initState() {
    super.initState();
    fileToolbarItems = getFileToolbarItems(widget.pageID);
    listenEventSelectFile =
        EventBusSingleton.instance.on<EventSelectFile>().listen((event) {
      if (event.pageID != widget.pageID) {
        return;
      }
      setState(() {});
    });
  }

  List<Widget> buildLandScapeToolbarWidgets() {
    List<Widget> result = [];
    for (Map item in fileToolbarItems) {
      if (!isShow(
          item["show_mode"], Global.filePages[widget.pageID]!.selectedCount)) {
        continue;
      }
      if (item["platform"] != null) {
        if (!kIsWeb) {
          if (!item["platform"].contains(Platform.operatingSystem)) {
            continue;
          }
        } else {
          if (!item["platform"].contains("web")) {
            continue;
          }
        }
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
      if (item.containsKey("children") && item["children"].length > 0) {
        List<PopupMenuItem<String>> menuItems =
            buildPopupMenuItems(context, item["children"]);

        result.add(PopupMenuButton<String>(
            tooltip: item["name"] is String ? item["name"] : item["name"](),
            itemBuilder: (context) => menuItems,
            onSelected: (value) =>
                onSelectPopupMenuItem(value, item["children"]),
            icon: Icon(item["icon"])));
        continue;
      }
      result.add(IconButton(
        splashRadius: 24,
        onPressed: item["onPressed"],
        icon: Icon(item["icon"],
            color: item.containsKey("enabled") && item["enabled"]
                ? Colors.orange
                : null),
        tooltip: item["name"] is String? item["name"] : item["name"](),
      ));
    }
    return result;
  }

  List<Widget> buildPortraitToolbarWidgets() {
    List<Widget> result = [];
    for (Map item in fileToolbarItems) {
      if (item["show_in_menu"] ||
          !isShow(item["show_mode"],
              Global.filePages[widget.pageID]?.selectedCount ?? 0)) {
        continue;
      }
      if (item["platform"] != null) {
        if (!kIsWeb) {
          if (!item["platform"].contains(Platform.operatingSystem)) {
            continue;
          }
        } else {
          if (!item["platform"].contains("web")) {
            continue;
          }
        }
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
      if (item.containsKey("children") && item["children"].length > 0) {
        List<PopupMenuItem<String>> menuItems =
            buildPopupMenuItems(context, item["children"]);

        result.add(PopupMenuButton<String>(
            tooltip: item["name"] is String? item["name"] : item["name"](),
            itemBuilder: (context) => menuItems,
            onSelected: (value) =>
                onSelectPopupMenuItem(value, item["children"]),
            icon: Icon(item["icon"])));
        continue;
      }
      result.add(IconButton(
        splashRadius: 24,
        onPressed: item["onPressed"],
        icon: Icon(item["icon"],
            color: item.containsKey("enabled") && item["enabled"]
                ? Colors.orange
                : null),
        tooltip: item["name"] is String? item["name"] : item["name"](),
      ));
    }
    result.add(PopupMenuButton(
      tooltip: "更多",
      itemBuilder: (context) => buildPopupMenuItems(context, fileToolbarItems),
      onSelected: (value) => onSelectPopupMenuItem(value, fileToolbarItems),
    ));
    return result;
  }

  void onSelectPopupMenuItem(String value, List items) {
    for (Map item in items) {
      if (item.toString() == value) {
        item["onPressed"]();
        break;
      }
      if (item.containsKey("children") && item["children"].length > 0) {
        onSelectPopupMenuItem(value, item["children"]);
      }
    }
  }

  List<PopupMenuItem<String>> buildPopupMenuItems(
      BuildContext context, List<dynamic> items) {
    List<PopupMenuItem<String>> result = [];
    for (Map item in items) {
      if (!item['show_in_menu'] ||
          !isShow(item["show_mode"],
              Global.filePages[widget.pageID]!.selectedCount)) {
        continue;
      }
      if (item["icon"] == null) {
        result.add(const PopupMenuItem<String>(
          enabled: false,
          height: 4,
          child: Divider(),
        ));
        continue;
      }
      if (item.containsKey("children") && item["children"].length > 0) {
        List<PopupMenuItem<String>> menuItems =
            buildPopupMenuItems(context, item["children"]);
        result.add(PopupMenuItem<String>(
          enabled: false,
          height: 4,
          child: Row(
            children: [
              Text(item["name"] is String? item["name"] : item["name"]()),
              SizedBox(width: 5),
              Expanded(
                  child: Divider(
                color: Colors.grey[300],
                height: 1,
                thickness: 1.0,
              ))
            ],
          ),
        ));
        result.addAll(menuItems);
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
            Text(item["name"] is String? item["name"] : item["name"]()),
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
