import 'dart:async';

import 'package:fileclient/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart';
import 'package:toastification/toastification.dart';
import '../backend/backend.dart';
import '../dialog/message_dialog.dart';
import '../global.dart';
import '../util.dart';

class MyDrawer extends StatefulWidget {
  const MyDrawer({super.key});

  @override
  State<MyDrawer> createState() => _MyDrawerState();
}

class _MyDrawerState extends State<MyDrawer> {
  List baseItems = [];

  late StreamSubscription<EventRefreshFavorites> listenEventRefreshFavorites;
  @override
  void dispose() {
    super.dispose();
    listenEventRefreshFavorites.cancel();
  }

  @override
  void initState() {
    super.initState();
    baseItems = [
      ListTile(
        minTileHeight: 32,
        leading: const Icon(Icons.folder),
        title: const Text("我的文件"),
        onTap: () {
          Global.filesKey.currentState?.createFilePage('/');
          if (Global.showMode == ShowMode.portrait) {
            Navigator.pop(context);
          }
        },
      ),
      ListTile(
        minTileHeight: 32,
        leading: const Icon(Icons.share),
        title: const Text("我的分享"),
        onTap: () {
          Global.filesKey.currentState?.gotoPage(PageType.shared);
          if (Global.showMode == ShowMode.portrait) {
            Navigator.pop(context);
          }
        },
      ),
    ];

    if (Global.userInfo.isAdmin) {
      baseItems.add(ListTile(
        minTileHeight: 32,
        leading: const Icon(Icons.monitor_heart),
        title: const Text("资源监控"),
        onTap: () {
          Global.filesKey.currentState?.gotoPage(PageType.serverMonitor);
          if (Global.showMode == ShowMode.portrait) {
            Navigator.pop(context);
          }
        },
      ));
    }

    listenEventRefreshFavorites =
        EventBusSingleton.instance.on<EventRefreshFavorites>().listen((event) {
      Backend.getFavorites(getFavorites, onFailed);
    });
    Future.delayed(const Duration(milliseconds: 200)).then((e) {
      if (Global.favoriteItems.isEmpty) {
        Backend.getFavorites(getFavorites, onFailed);
      }

      Global.initVersion((result) {
        setState(() {});
      });
    });
  }

  void getFavorites(result) {
    if (result["code"] != 0) {
      toastification.show(
        title: const Text("获取收藏夹失败"),
        description: Text("${result["code"]}: ${result["message"]}"),
        type: ToastificationType.error,
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
    Global.favoriteItems.clear();
    for (var item in result["data"]) {
      Global.favoriteItems.add(item);
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> onDeleteFavorites(var favriteItem) async {
    MessageDialogResult? result = await showMessageDialog(
        context, "提醒", "确定要删除收藏夹(${favriteItem["name"]})吗？");
    if (result == null || result != MessageDialogResult.ok) {
      return;
    }
    Backend.deleteFavorites(favriteItem['id'], (result) {
      if (result["code"] != 0) {
        toastification.show(
          title: const Text("删除收藏夹失败"),
          description: Text("${result["code"]}: ${result["message"]}"),
          type: ToastificationType.error,
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
      EventBusSingleton.instance.fire(EventRefreshFavorites());
    }, onFailed);
  }

  Widget buildItem(BuildContext context, int index) {
    if (index < baseItems.length) {
      return Container(
        margin: const EdgeInsets.all(5),
        child: baseItems[index],
      );
    } else if (index == baseItems.length) {
      return const ListTile(
          minTileHeight: 32,
          title: Padding(
            padding: EdgeInsets.only(left: 1, right: 1),
            child: Row(
              children: [
                Expanded(
                    child: Divider(
                  color: Colors.grey,
                  height: 1,
                  thickness: 1.0,
                )),
                Text(
                  "我的收藏",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Expanded(
                    child: Divider(
                  color: Colors.grey,
                  height: 1,
                  thickness: 1.0,
                )),
              ],
            ),
          ));
    }
    dynamic favriteItem = Global.favoriteItems[index - baseItems.length - 1];
    return Container(
      margin: const EdgeInsets.all(5),
      child: ListTile(
          minVerticalPadding: 0,
          leading: const Icon(Icons.folder),
          title: Transform(
            transform: Matrix4.translationValues(-16, 0.0, 0.0),
            child: Text(favriteItem['name']),
          ),
          trailing: IconButton(
              splashRadius: 24,
              onPressed: () => onDeleteFavorites(favriteItem),
              icon: const Icon(Icons.delete)),
          onTap: () {
            Global.filesKey.currentState?.createFilePage(favriteItem['path']);
            if (Global.showMode == ShowMode.portrait) {
              Navigator.pop(context);
            }
          }),
    );
  }

  List<PopupMenuItem<String>> buildUserPopupMenuItems(BuildContext context) {
    List<PopupMenuItem<String>> result = [];
    result.add(const PopupMenuItem(
        value: "logout",
        child: Row(
          children: [
            Icon(
              Icons.logout,
              color: Colors.blue,
            ),
            SizedBox(width: 8),
            Text("切换用户"),
          ],
        )));
    result.add(const PopupMenuItem(
        value: "exit",
        child: Row(
          children: [
            Icon(
              Icons.exit_to_app,
              color: Colors.blue,
            ),
            SizedBox(width: 8),
            Text("退出程序"),
          ],
        )));
    return result;
  }

  void onSelectUserPopupMenuItem(String value) {
    switch (value) {
      case "logout":
        Global.token = "";
        Global.sessionId = "";
        Global.userInfo = UserInfo();
        Navigator.pushReplacementNamed(context, "/login");
        break;
      case "exit":
        SystemNavigator.pop();
        break;
      case "settings":
        Global.filesKey.currentState?.gotoPage(PageType.settings);
        break;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
        child: Flex(direction: Axis.vertical, children: <Widget>[
      Expanded(
        child: ListView.builder(
            itemBuilder: buildItem,
            itemCount: baseItems.length + Global.favoriteItems.length + 1),
      ),
      Container(
        margin: const EdgeInsets.only(left: 15),
        alignment: Alignment.centerLeft,
        child: Global.showMode == ShowMode.landScape
            ? null
            : Row(
                children: [
                  PopupMenuButton(
                      tooltip: "用户信息",
                      position: PopupMenuPosition.under,
                      itemBuilder: (context) =>
                          buildUserPopupMenuItems(context),
                      onSelected: onSelectUserPopupMenuItem,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Ionicons.person, color: Colors.grey),
                          Text(Global.username,
                              style: const TextStyle(color: Colors.grey)),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey)
                        ],
                      )),
                  Spacer(),
                  IconButton(
                      splashRadius: 16,
                      onPressed: () => onSelectUserPopupMenuItem("settings"),
                      icon: Icon(
                        Icons.settings_outlined,
                        color: Colors.grey,
                      ))
                ],
              ),
      ),
      const SizedBox(
        height: 5,
      )
    ]));
  }
}
