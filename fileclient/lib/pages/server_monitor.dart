import 'package:flutter/material.dart';
import 'base_page.dart';
import 'server/server_base.dart';
import 'server/server_cpu.dart';
import 'server/server_disk.dart';
import 'server/server_memory.dart';
import 'server/server_network.dart';
import 'server/server_process.dart';

import '../global.dart';

class ServerMonitorPage extends BasePage {
  const ServerMonitorPage({super.key});
  @override
  String getTitle() {
    return '资源监控';
  }

  @override
  IconData getIcon() {
    return Icons.monitor_heart;
  }

  @override
  int getPageID() => PageType.serverMonitor.index;

  @override
  PageType getPageType() {
    return PageType.serverMonitor;
  }

  @override
  Widget getToolbar(bool isLandScape) {
    return Container();
  }

  @override
  State<ServerMonitorPage> createState() => _ServerMonitorPageState();
}

class _ServerMonitorPageState extends State<ServerMonitorPage> {
  List<Widget> _tabItems = [];
  List<Widget> _tabPages = [];
  @override
  void initState() {
    super.initState();
      _tabItems = [
        const Tab(text: '概览'),
        const Tab(text: '处理器'),
        const Tab(text: '内存'),
        const Tab(text: '网络'),
        const Tab(text: '硬盘'),
        //const Tab(text: '进程'),
      ];
      _tabPages = [
        const Center(
          child: ServerBaseInfo(),
        ),
        const Center(
          child: ServerCpuInfo(),
        ),
        const Center(
          child: ServerMemoryInfo(),
        ),
        const Center(
          child: ServerNetworkInfo(),
        ),
        const Center(
          child: ServerDiskInfo(),
        ),
        /*const Center(
          child: ServerProcessInfo(),
        ),*/
      ];
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
