import 'dart:async';

import 'package:dynamic_tabbar/dynamic_tabbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_resizable_container/flutter_resizable_container.dart';
import 'package:ionicons/ionicons.dart';
import 'package:toastification/toastification.dart';

import '../dialog/input_dialog.dart';
import 'server_monitor.dart';
import 'util/desktop_check.dart' if (dart.library.html) 'util/web_check.dart';
import '../backend/task_manager.dart';
import '../backend/backend.dart';
import '../dialog/task_dialog.dart';
import '../event.dart';
import '../global.dart';
import '../util.dart';
import 'base_page.dart';
import 'files.dart';
import 'mydrawer.dart';
import 'settings.dart';
import 'shared.dart';
import 'xterm.dart';
import 'keep_alive_wrapper.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final List<BasePage> _pages = [
    FilesPage(
        pageID: PageType.serverFiles.index, key: GlobalKey(debugLabel: 'init')),
  ];
  late StreamSubscription<EventClipboard> listenEventClipboard;
  late StreamSubscription<EventUpdateTitle> listenEventUpdateTitle;
  late StreamSubscription<EventTasksChanged> listenEventTasksChanged;
  final List<EventClipboard> _clipboard = [];
  int _tabIndex = 0;
  late TabController? _controller;

  @override
  void initState() {
    super.initState();
    disableWebBrowerRightClick();
    Global.logger?.i("init home page");
    if (!kIsWeb) {
      Global.taskManager = TaskManager();
    }

    listenEventTasksChanged =
        EventBusSingleton.instance.on<EventTasksChanged>().listen((evnt) {
      setState(() {});
    });

    listenEventClipboard =
        EventBusSingleton.instance.on<EventClipboard>().listen((event) {
      _clipboard.add(event);
      setState(() {});
    });
    listenEventUpdateTitle =
        EventBusSingleton.instance.on<EventUpdateTitle>().listen((event) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
    Future.delayed(const Duration(milliseconds: 200)).then((e) {
      EventBusSingleton.instance.fire(EventRefreshFavorites());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    super.dispose();
    listenEventClipboard.cancel();
    listenEventTasksChanged.cancel();
    Global.taskManager = null;
  }

  int createFilePage(String defaultPath) {
    // 如果已经打开了该文件，则切换到该文件
    for (var page in Global.filePages.values) {
      if (page.path != defaultPath) {
        continue;
      }
      for (int index = 0; index < _pages.length; index++) {
        if (_pages[index].getPageID() == page.pageID) {
          _tabIndex = index;
          Global.currentPageID = _pages[_tabIndex].getPageID();
          _controller?.index = index;
          setState(() {});
          return page.pageID;
        }
      }
    }
    // 如果没有打开，则新建一个文件
    int pageID = Global.allowPageID();
    Global.filePages[pageID] = PageData(defaultPath, pageID, 0);
    _pages.add(FilesPage(
      pageID: pageID,
      key: GlobalKey(debugLabel: defaultPath),
    ));
    int tabIndex = _pages.length - 1;
    setState(() {});
    Future.delayed(Duration(milliseconds: 200), () {
      _tabIndex = tabIndex;
      Global.currentPageID = _pages[_tabIndex].getPageID();
      _controller?.index = tabIndex;
      setState(() {});
    });
    return pageID;
  }

  int createXtermPage(XtermConfig cfg, String xtermFilePath) {
    int pageID = Global.allowPageID();
    _pages.add(XtermPage(
      pageID: pageID,
      cfg: cfg,
      xtermFilePath: xtermFilePath,
      key: GlobalKey(debugLabel: xtermFilePath),
    ));
    int tabIndex = _pages.length - 1;
    setState(() {});

    Future.delayed(const Duration(milliseconds: 200), () {
      _tabIndex = tabIndex;
      Global.currentPageID = _pages[_tabIndex].getPageID();
      _controller?.index = tabIndex;
      setState(() {});
    });
    return pageID;
  }

  void closePage(int pageID) {
    for (int index = 0; index < _pages.length; index++) {
      if (_pages[index].getPageID() == pageID) {
        if (index == _tabIndex) {
          _tabIndex = index > 0 ? index - 1 : 0;
          Global.currentPageID = _pages[_tabIndex].getPageID();
          _controller?.index = _tabIndex;
        } else if (index < _tabIndex) {
          _tabIndex--;
        }
        _pages.removeAt(index);
        Global.filePages.remove(pageID);
        setState(() {});
        break;
      }
    }
    setState(() {});
  }

  void switchToPage(int pageID) {
    for (int index = 0; index < _pages.length; index++) {
      if (_pages[index].getPageID() == pageID) {
        _tabIndex = index;
        Global.currentPageID = _pages[_tabIndex].getPageID();
        _controller?.index = index;
        setState(() {});
        break;
      }
    }
  }

  int gotoPage(PageType page) {
    int tabIndex = -1;
    for (int index = 0; index < _pages.length; index++) {
      if (_pages[index].getPageType() == page) {
        tabIndex = index;
        _tabIndex = index;
        setState(() {});
        Global.currentPageID = _pages[_tabIndex].getPageID();
        break;
      }
    }
    if (tabIndex == -1) {
      switch (page) {
        case PageType.serverFiles:
          {
            int pageID = PageType.serverFiles.index;
            _pages.add(
                FilesPage(pageID: pageID, key: GlobalKey(debugLabel: '/')));
            Future.delayed(Duration(milliseconds: 200), () {
              EventBusSingleton.instance.fire(EventGotoPath(pageID, '/'));
            });
          }
          break;
        case PageType.shared:
          _pages.add(SharedPage(key: GlobalKey(debugLabel: 'shared')));
          break;
        case PageType.settings:
          _pages.add(SettingsPage(key: GlobalKey(debugLabel: 'setting')));
          break;
        case PageType.xterm:
          throw UnimplementedError();
        case PageType.serverMonitor:
          _pages.add(ServerMonitorPage(key: GlobalKey(debugLabel: 'server')));
      }
      tabIndex = _pages.length - 1;
      Future.delayed(Duration(milliseconds: 200), () {
        _tabIndex = tabIndex;
        Global.currentPageID = _pages[_tabIndex].getPageID();
        _controller?.index = tabIndex;
        setState(() {});
      });
    } else {
      _tabIndex = tabIndex;
      Global.currentPageID = _pages[_tabIndex].getPageID();
      _controller?.index = tabIndex;
      setState(() {});
    }

    setState(() {});
    return _pages[tabIndex].getPageID();
  }

  List<PopupMenuEntry<int>> buildPagesListMenu(BuildContext context) {
    List<PopupMenuEntry<int>> result = [];
    for (var page in _pages) {
      int pageID = page.getPageID();
      result.add(PopupMenuItem(
        value: pageID,
        child: Row(
          children: [
            Icon(page.getIcon(),
                color:
                    pageID == Global.currentPageID ? Colors.blue : Colors.grey),
            SizedBox(width: 8),
            Text(page.getTitle()),
          ],
        ),
      ));
    }
    return result;
  }

  Widget buildPortraitBody(BuildContext context) {
    return DynamicTabBarWidget(
      physics: NeverScrollableScrollPhysics(),
      physicsTabBarView: NeverScrollableScrollPhysics(),
      trailing: Global.filePages.length <= 1
          ? null
          : PopupMenuButton(
              tooltip: "切换标签页",
              itemBuilder: buildPagesListMenu,
              position: PopupMenuPosition.under,
              onSelected: (pageID) => switchToPage(pageID),
              child: const Icon(Icons.arrow_drop_down, color: Colors.grey),
            ),
      indicatorWeight: 1,
      isScrollable: true,
      showBackIcon: false,
      showNextIcon: false,
      padding: const EdgeInsets.only(left: 5, right: 5, top: 0, bottom: 0),
      labelPadding: const EdgeInsets.all(0),
      indicatorPadding: const EdgeInsets.all(0),
      dynamicTabs: getTabs(),
      onAddTabMoveTo: MoveToTab.last,
      onTabControllerUpdated: (controller) {
        _controller = controller;
        Future.delayed(Duration(milliseconds: 200), () {
          if (_tabIndex != _controller?.index) {
            _controller?.index = _tabIndex;
            setState(() {});
          }
        });
      },
      onTabChanged: (index) {
        _tabIndex = index ?? 0;
        Global.currentPageID = _pages[_tabIndex].getPageID();
        setState(() {});
      },
    );
  }

  final TextStyle _tabTitleTextStyle = TextStyle(fontSize: 16);
  List<TabData> getTabs() {
    List<TabData> result = [];
    int index = 0;
    for (var page in _pages) {
      String title = page.getTitle();
      int pageID = page.getPageID();

      final textPainter = TextPainter(
        text: TextSpan(text: title, style: _tabTitleTextStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(); // 计算文本的布局
      double width = textPainter.width; // 获取文本宽度
      if (width > 100) {
        width = 100;
      }

      result.add(TabData(
        index: index,
        content: KeepAliveWrapper(child: page),
        title: Tab(
            child: Container(
                margin: EdgeInsets.symmetric(vertical: 4, horizontal: 0.5),
                width: pageID == PageType.serverFiles.index
                    ? width + 60
                    : width + 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                  color: index == _tabIndex ? Colors.blue : Colors.transparent,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 8),
                    Icon(
                      page.getIcon(),
                      size: 16,
                      color: index == _tabIndex ? Colors.white : Colors.grey,
                    ),
                    SizedBox(width: 4),
                    SizedBox(
                      width: width,
                      child: Text(
                        page.getTitle(),
                        softWrap: true,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: index == _tabIndex
                                ? Colors.white
                                : Colors.grey),
                      ),
                    ),
                    Spacer(),
                    page.getPageID() == PageType.serverFiles.index
                        ? Container()
                        : IconButton(
                            padding: EdgeInsets.zero,
                            splashRadius: 16,
                            onPressed: () => closePage(page.getPageID()),
                            hoverColor: Colors.white,
                            focusColor: Colors.white,
                            color:
                                index == _tabIndex ? Colors.white : Colors.grey,
                            icon: Icon(
                              Icons.close,
                              size: 16,
                            )),
                  ],
                ))),
      ));
      index++;
    }
    return result;
  }

  final double _leftWidth = 240;
  Widget buildLandscapeBody(BuildContext context) {
    return ResizableContainer(direction: Axis.horizontal, children: [
      ResizableChild(
        divider: ResizableDivider(thickness: 2),
        size: ResizableSize.pixels(_leftWidth, min: 200, max: 560),
        child: _pages[_tabIndex].getSidebar() ?? MyDrawer(),
      ),
      ResizableChild(
        child: DynamicTabBarWidget(
          physics: NeverScrollableScrollPhysics(),
          physicsTabBarView: NeverScrollableScrollPhysics(),
          trailing: Global.filePages.length <= 1
              ? null
              : PopupMenuButton(
                  tooltip: "切换标签页",
                  itemBuilder: buildPagesListMenu,
                  position: PopupMenuPosition.under,
                  onSelected: (pageID) => switchToPage(pageID),
                  child: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ),
          isScrollable: true,
          showBackIcon: false,
          showNextIcon: false,
          padding: const EdgeInsets.only(left: 10, right: 10),
          labelPadding: const EdgeInsets.all(0),
          indicatorPadding: const EdgeInsets.all(0),
          dynamicTabs: getTabs(),
          onAddTabMoveTo: MoveToTab.last,
          onTabControllerUpdated: (controller) {
            _controller = controller;
            Future.delayed(Duration(milliseconds: 200), () {
              if (_tabIndex != _controller?.index) {
                _controller?.index = _tabIndex;
                setState(() {});
              }
            });
          },
          onTabChanged: (index) {
            _tabIndex = index ?? 0;
            Global.currentPageID = _pages[_tabIndex].getPageID();
            setState(() {});
          },
        ),
      )
    ]);
  }

  bool isKeyboardVisible() {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }

  Widget buildBody(BuildContext context, Orientation orientation) {
    while (orientation == Orientation.landscape) {
      // 如果是手机并且键盘可见且手机不是横向则不切换布局
      if (isMobile() &&
          isKeyboardVisible() &&
          MediaQuery.of(context).orientation != Orientation.landscape) {
        break;
      }
      // 横向布局
      if (Global.showMode != ShowMode.landScape) {
        Future.delayed(const Duration(milliseconds: 200), () {
          setState(() {
            Global.showMode = ShowMode.landScape;
          });
          EventBusSingleton.instance
              .fire(EventGotoPath(_pages[_tabIndex].getPageID(), ""));
        });
      }
      return buildLandscapeBody(context);
    }

    // 纵向布局
    if (Global.showMode != ShowMode.portrait) {
      Future.delayed(const Duration(milliseconds: 200), () {
        setState(() {
          Global.showMode = ShowMode.portrait;
        });
        EventBusSingleton.instance
            .fire(EventGotoPath(_pages[_tabIndex].getPageID(), ""));
      });
    }
    return buildPortraitBody(context);
  }

  Widget getToolbar() {
    return _pages[_tabIndex].getToolbar(Global.showMode == ShowMode.landScape);
  }

  Future<void> onClipboard() async {
    for (var item in _clipboard) {
      switch (item.action) {
        case ClipboardAction.copy:
          String destFolder = Global.getPagePath(Global.currentPageID);
          String destFile = joinPath([destFolder, baseName(item.path)]);
          // 如果源和目标相同则提示需要改名。
          if (destFolder == dirName(item.path)) {
            String? newName = await showInputDialog(
              context,
              title: "请输入新的文件名",
              value: baseName(item.path),
            );
            if (newName == null) {
              return;
            }
            destFile = joinPath([destFolder, newName]);
          }
          Backend.copyFile(item.path, destFile, (result) {
            if (result["code"] != 0) {
              toastification.show(
                title: Text(result["msg"]),
                autoCloseDuration: const Duration(seconds: 3),
              );
              return;
            }
            _clipboard.remove(item);
            setState(() {});
            EventBusSingleton.instance
                .fire(EventGotoPath(_pages[_tabIndex].getPageID(), ""));
          }, onFailed);
          break;
        case ClipboardAction.cut:
          String destFolder = Global.getPagePath(Global.currentPageID);
          String destFile = joinPath([destFolder, baseName(item.path)]);
          // 如果源和目标相同则提示需要改名。
          if (destFolder == dirName(item.path)) {
            toastification.show(
              title: const Text("源和目标相同，已忽略"),
              autoCloseDuration: const Duration(seconds: 3),
            );
            _clipboard.remove(item);
            return;
          }
          Backend.moveFile(item.path, destFile, (result) {
            if (result["code"] != 0) {
              toastification.show(
                title: Text(result["msg"]),
                autoCloseDuration: const Duration(seconds: 3),
              );
              return;
            }
            _clipboard.remove(item);
            setState(() {});
            EventBusSingleton.instance
                .fire(EventGotoPath(_pages[_tabIndex].getPageID(), ""));
          }, onFailed);
          break;
      }
    }
  }

  String getClipboardText() {
    String result = "";
    for (var item in _clipboard) {
      if (result.isNotEmpty) {
        result += "\n";
      }
      result += "${item.action.name}: ${item.path}";
    }
    return result;
  }

  List<PopupMenuItem<String>> buildPopupMenuItems(BuildContext context) {
    List<PopupMenuItem<String>> result = [];
    int copyCount = 0, moveCount = 0;
    for (var item in _clipboard) {
      switch (item.action) {
        case ClipboardAction.copy:
          copyCount++;
          break;
        case ClipboardAction.cut:
          moveCount++;
          break;
      }
    }
    String task = "";
    if (moveCount > 0) {
      task += "$moveCount个剪切";
    }
    if (copyCount > 0) {
      if (task.isNotEmpty) {
        task += "和";
      }
      task += "$copyCount个复制";
    }
    result.add(PopupMenuItem(
        value: "exec",
        child: Row(
          children: [
            const Icon(
              Ionicons.clipboard,
              color: Colors.blue,
            ),
            const SizedBox(width: 8),
            Text("开始执行($task)"),
          ],
        )));
    result.add(const PopupMenuItem(
        value: "clear",
        child: Row(
          children: [
            Icon(
              Ionicons.trash,
              color: Colors.blue,
            ),
            SizedBox(width: 8),
            Text("清空剪贴板"),
          ],
        )));
    return result;
  }

  void onSelectPopupMenuItem(String value) {
    if (value == "exec") {
      onClipboard();
    }
    if (value == "clear") {
      _clipboard.clear();
      setState(() {});
    }
  }

  void onUserSetting() {
    gotoPage(PageType.settings);
  }

  List<PopupMenuItem<String>> buildUserPopupMenuItems(BuildContext context) {
    List<PopupMenuItem<String>> result = [];
    result.add(const PopupMenuItem(
        value: "settings",
        child: Row(
          children: [
            Icon(
              Icons.settings_outlined,
              color: Colors.blue,
            ),
            SizedBox(width: 8),
            Text("用户设置"),
          ],
        )));
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
        gotoPage(PageType.settings);
        break;
    }
  }

  void onShowTask() {
    showTaskDialog(context, title: "任务列表");
  }

  Widget getTaskIcon() {
    if (Global.taskManager == null || Global.taskManager!.tasks.isEmpty) {
      return const SizedBox();
    }
    int count = 0;
    Color color = Colors.red;
    for (TransTaskItem task in Global.taskManager!.tasks) {
      if (task.status != TransStatus.succeed &&
          task.status != TransStatus.failed) {
        count++;
      }
    }
    if (count == 0) {
      color = Colors.green;
      count = Global.taskManager!.tasks.length;
    }
    Widget icon = Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Ionicons.list_circle_outline,
          size: 32,
        ),
        Positioned(
          right: 0.0,
          top: 0.0,
          child: CircleAvatar(
            backgroundColor: color,
            radius: 8.0,
            child: Text(
              count.toString(),
              style: TextStyle(color: Colors.white, fontSize: 11), // 角标文字样式
            ),
          ),
        ),
      ],
    );
    return Tooltip(
      message: "任务列表",
      child: IconButton(onPressed: onShowTask, iconSize: 32, icon: icon),
    );
  }

  Widget buildScaffold(BuildContext content) {
    return Scaffold(
      appBar: AppBar(
        leading: Global.showMode != ShowMode.portrait
            ? null
            : Builder(
                builder: (BuildContext context) {
                  return IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () {
                      Scaffold.of(context).openDrawer();
                    },
                    tooltip: "打开导航菜单",
                  );
                },
              ),
        title: Global.showMode != ShowMode.landScape
            ? null
            : PopupMenuButton(
                tooltip: "用户信息",
                itemBuilder: (context) => buildUserPopupMenuItems(context),
                onSelected: onSelectUserPopupMenuItem,
                offset: const Offset(0, 36),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Ionicons.person),
                    Text(
                      Global.username,
                      style: const TextStyle(color: Colors.white, fontSize: 24),
                    ),
                    const Icon(Icons.arrow_drop_down)
                  ],
                )),
        actions: [
          getTaskIcon(),
          Visibility(
            visible: _clipboard.isNotEmpty,
            child: Tooltip(
              message: "剪贴板(${_clipboard.length})\n${getClipboardText()}",
              child: PopupMenuButton(
                  itemBuilder: (context) => buildPopupMenuItems(context),
                  onSelected: onSelectPopupMenuItem,
                  icon: const Icon(Ionicons.clipboard_outline)),
            ),
          ),
          getToolbar(),
        ],
      ),
      drawer: Global.showMode == ShowMode.portrait
          ? _pages[_tabIndex].getSidebar() ?? MyDrawer()
          : null,
      body: OrientationBuilder(builder: buildBody),
    );
  }

  DateTime? lastPopScopeTime;
  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return buildScaffold(context);
    }
    return PopScope(
        onPopInvokedWithResult: (bool didPop, result) async {
          // 如果当前路径是根目录则退出程序
          int currentPageID = _pages[_tabIndex].getPageID();
          String currentPagePath = Global.getPagePath(currentPageID);

          // 如果不是根目录则返回上一级目录
          if (currentPagePath != "/") {
            EventBusSingleton.instance
                .fire(EventGotoPath(currentPageID, dirName(currentPagePath)));
            return;
          }

          // 如果不是文件页则直接关闭当前页
          if (_tabIndex != PageType.serverFiles.index) {
            closePage(currentPageID);
            return;
          }

          // 如果是文件页则提示是否退出程序
          if (lastPopScopeTime == null ||
              DateTime.now().difference(lastPopScopeTime!) >
                  const Duration(seconds: 2)) {
            lastPopScopeTime = DateTime.now();
            toastification.show(
              title: const Text("再按一次退出程序"),
              autoCloseDuration: const Duration(seconds: 2),
            );
            return;
          }
          // 已经无路可退，退出程序
          SystemNavigator.pop();
        },
        canPop: false,
        child: buildScaffold(
          context,
        ));
  }
}
