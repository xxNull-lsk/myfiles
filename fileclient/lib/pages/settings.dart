import 'package:fileclient/pages/base_page.dart';
import 'package:fileclient/pages/settings_server.dart';
import 'package:flutter/material.dart';

import '../global.dart';
import 'settings_log.dart';
import 'settings_user.dart';
import 'settings_users.dart';

class SettingsPage extends BasePage {
  const SettingsPage({super.key});
  @override
  String getTitle() {
    return '设置';
  }

  @override
  IconData getIcon() {
    return Icons.settings;
  }

  @override
  int getPageID() => PageType.settings.index;

  @override
  PageType getPageType() {
    return PageType.settings;
  }

  @override
  Widget getToolbar(bool isLandScape) {
    return Container();
  }

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<Widget> _tabItems = [];
  List<Widget> _tabPages = [];
  @override
  void initState() {
    super.initState();
    if (Global.userInfo.isAdmin) {
      _tabItems = [
        const Tab(text: '个人设置'),
        const Tab(text: '日志设置'),
        const Tab(text: '用户管理'),
        const Tab(text: '服务器信息'),
      ];
      _tabPages = [
        const Center(
          child: SettingsUserPage(),
        ),
        const Center(
          child: SettingsLogPage(),
        ),
        const Center(
          child: SettingsUsersPage(),
        ),
        const Center(
          child: SettingsServerPage(),
        ),
      ];
    } else {
      _tabItems = [
        const Tab(text: '个人设置'),
        const Tab(text: '日志设置'),
      ];
      _tabPages = [
        const Center(
          child: SettingsUserPage(),
        ),
        const Center(
          child: SettingsLogPage(),
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabItems.length,
      child: Scaffold(
        appBar: AppBar(
          title: TabBar(
            tabs: _tabItems,
          ),
        ),
        body: TabBarView(
          children: _tabPages,
        ),
      ),
    );
  }
}
