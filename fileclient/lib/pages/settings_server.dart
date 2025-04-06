import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../backend/backend.dart';
import '../global.dart';
import '../util.dart';
import 'loading.dart';
import '../pages/util/desktop_check.dart'
    if (dart.library.html) '../pages/util/web_check.dart';

class ServerOs {
  DateTime bootTime = DateTime.now();
  String platform = "";
  String family = "";
  String version = "";
  String kernelVersion = "";
  String kernelArch = "";
  String virtualizationSystem = "";
  String virtualizationRole = "";
  ServerOs.fromMap(Map map) {
    bootTime = DateTime.parse(map["boot_time"] ?? "1970-01-01 00:00:00");
    platform = map["platform"] ?? "";
    family = map["family"] ?? "";
    version = map["version"] ?? "";
    kernelVersion = map["kernel_version"] ?? "";
    kernelArch = map["kernel_arch"] ?? "";
    virtualizationRole = map["virtualization_role"] ?? "";
    virtualizationSystem = map["virtualization_system"] ?? "";
  }
}

class ServerCpu {
  int physicalCount = 0;
  int logicalCount = 0;
  List<double> totalPercent = [];
  List<double> perPercents = [];
  List cpuInfos = [];
  ServerCpu.fromMap(Map map) {
    physicalCount = map["physical_count"] ?? 0;
    logicalCount = map["logical_count"] ?? 0;
    totalPercent.clear();
    if (map["total_percent"] != null) {
      for (var element in map["total_percent"]) {
        totalPercent.add(double.parse(element.toString()));
      }
    }
    perPercents.clear();
    if (map["per_percents"] != null) {
      for (var element in map["per_percents"]) {
        perPercents.add(double.parse(element.toString()));
      }
    }
    cpuInfos = List.from(map["info"] ?? []);
  }
}

class ServerMemory {
  int total = 1;
  int available = 0;
  int swaptotal = 1;
  int swapused = 0;
  int used = 0;
  int free = 0;
  ServerMemory.fromMap(Map map) {
    total = map["total"] ?? 1;
    available = map["available"] ?? 0;
    swaptotal = map["swaptotal"] ?? 1;
    int swapfree = map["swapfree"] ?? 0;
    swapused = swaptotal - swapfree;
    used = map["used"] ?? 0;
    free = map["free"] ?? 0;
  }
}

class ServerPartition {
  String path = "";
  String fstype = "";
  int total = 1;
  int used = 0;
  int free = 0;
  double usedPercent = 0;
  ServerPartition.fromMap(Map map) {
    path = map["path"] ?? "";
    fstype = map["fstype"] ?? "";
    total = map["total"] ?? 1;
    used = map["used"] ?? 0;
    free = map["free"] ?? 0;
    usedPercent = map["usedPercent"] ?? 0;
  }
}

class ServerUser {
  String name = "";
  String terminal = "";
  String host = "";
  int started = 0;
  ServerUser.fromMap(Map map) {
    name = map["user"] ?? "";
    terminal = map["terminal"] ?? "";
    host = map["host"] ?? "";
    started = map["started"] ?? 0;
  }
}

class SettingsServerPage extends StatefulWidget {
  const SettingsServerPage({super.key});

  @override
  State<SettingsServerPage> createState() => _SettingsServerPageState();
}

class _SettingsServerPageState extends State<SettingsServerPage> {
  bool _autoRefresh = true;
  var _loading = false;
  ServerOs _os = ServerOs.fromMap({});
  ServerCpu _cpu = ServerCpu.fromMap({});
  ServerMemory _memory = ServerMemory.fromMap({});
  final List<ServerPartition> _partitions = [];
  final List<ServerUser> _users = [];
  Timer? _timer;
  @override
  void initState() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = true;
      });
      Backend.getServerInfo(
          (res) => (!mounted)
              ? null
              : setState(() {
                  _loading = false;
                  onServerInfoSucceed(res);
                }),
          onFailed, false, "1s");
    });

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_autoRefresh) {
        Backend.getServerInfo(onServerInfoSucceed, onFailed, true, "1s");
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void onServerInfoSucceed(Map info) {
    _os = ServerOs.fromMap(info["os"]);
    _cpu = ServerCpu.fromMap(info["cpu"]);
    _memory = ServerMemory.fromMap(info["memory"]);
    _partitions.clear();
    for (var element in info["partitions"]) {
      _partitions.add(ServerPartition.fromMap(element));
    }
    _users.clear();
    for (var element in info["users"]) {
      _users.add(ServerUser.fromMap(element));
    }
    if (mounted) {
      setState(() {});
    }
  }

  void onAutoRefreshChanged(bool value) {
    _autoRefresh = value;
    if (mounted) {
      setState(() {});
    }
  }

  Widget? onItemBuilder(BuildContext context, int index) {
    EdgeInsets edge = EdgeInsets.only(left: 32, right: 32);
    switch (index) {
      case 1:
        return SwitchListTile(
            value: _autoRefresh,
            title: Text("自动刷新"),
            onChanged: onAutoRefreshChanged);
      case 2:
        return Padding(
          padding: edge,
          child: getOSCard(),
        );
      case 3:
        return Padding(padding: edge, child: getCpuCard());
      case 4:
        return Padding(padding: edge, child: getMemoryCard());
      case 5:
        return Padding(padding: edge, child: getDiskCard());
      case 6:
        return Padding(padding: edge, child: getUserCard());
      case 0:
        return getServerInfo();
    }
    return null;
  }

  Widget getServerInfo() {
    return ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      children: [
        ListTile(
          leading: Text("名称"),
          title: Text(Global.serverVersion.name),
        ),
        ListTile(
          leading: Text("版本"),
          title: Text(Global.serverVersion.version),
        ),
        ListTile(
          leading: Text("编译时间"),
          title: Text(Global.serverVersion.time),
        ),
        ListTile(
          leading: Text("代码版本"),
          title: Text(Global.serverVersion.commit),
        ),
        Global.serverVersion.url.isEmpty
            ? Container()
            : ListTile(
                leading: Text("网址"),
                title: MouseRegion(
                  cursor: SystemMouseCursors.click, // 设置鼠标悬停时光标为手型
                  child: GestureDetector(
                      onTap: () => openUrl(Global.serverVersion.url, true),
                      child: Text(Global.serverVersion.url,
                          style: TextStyle(
                            color: Colors.blue,
                          ))),
                ),
              ),
      ],
    );
  }

  Widget getOSCard() {
    DateFormat formatter = DateFormat("yyyy-MM-dd HH:mm:ss");
    return SizedBox(
      height: 280,
      child: Card(
        child: ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text("操作系统信息"),
              subtitle: Text(
                  "启动时间:${humanizerDatetime(_os.bootTime, withRemain: true)} ${formatter.format(_os.bootTime)}"),
            ),
            ListTile(
              title: Text("系统"),
              trailing: Text(_os.platform),
              subtitle: Text("${_os.family} - ${_os.version}"),
            ),
            ListTile(
              title: Text("内核"),
              trailing: Text(_os.kernelArch),
              subtitle: Text(_os.kernelVersion),
            ),
            ListTile(
              title: Text("虚拟化"),
              trailing: Text(_os.virtualizationSystem),
              subtitle: Text(_os.virtualizationRole),
            ),
          ],
        ),
      ),
    );
  }

  Widget getCpuCard() {
    List<Widget> children = [];
    for (var i = 0; i < _cpu.perPercents.length; i++) {
      var e = _cpu.perPercents[i];
      children.add(
        SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                "${e.toStringAsFixed(2)}%",
                style: TextStyle(fontSize: 12),
              ),
              SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    strokeWidth: 6,
                    backgroundColor: Colors.grey,
                    value: e / 100,
                  ))
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 280,
      child: Card(
        child: ListView(
          children: [
            ListTile(
              title: Text("CPU信息 (${_cpu.physicalCount}/${_cpu.logicalCount})"),
              trailing: Text(""),
              subtitle: Text(
                  "${_cpu.cpuInfos.isEmpty ? "" : _cpu.cpuInfos[0]["modelName"]}"),
            ),
            ListTile(
              title: Text(
                  "总使用率 ${_cpu.totalPercent.map((e) => "${e.toStringAsFixed(2)}%").join(", ")}"),
              subtitle: LinearProgressIndicator(
                value: _cpu.totalPercent.isEmpty
                    ? 0
                    : _cpu.totalPercent
                            .reduce((value, element) => value + element) /
                        _cpu.totalPercent.length /
                        100,
              ),
            ),
            ListTile(
              title: Text("CPU核心使用率(${children.length})"),
              subtitle: Padding(
                padding: EdgeInsets.only(top: 8, bottom: 8),
                child: Wrap(
                  spacing: 32,
                  runSpacing: 16,
                  children: children,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget getMemoryCard() {
    return SizedBox(
      height: 150,
      child: Card(
        child: ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                  "内存信息 ${formatBytes(_memory.used, 2)} / ${formatBytes(_memory.total, 2)}"),
              subtitle: LinearProgressIndicator(
                value: _memory.used / _memory.total,
              ),
            ),
            ListTile(
              title: Text(
                  "交换内存 ${formatBytes(_memory.swapused, 2)} / ${formatBytes(_memory.swaptotal, 2)}"),
              subtitle: LinearProgressIndicator(
                value: _memory.swapused / _memory.swaptotal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget getDiskCard() {
    List<Widget> children = [];
    children.add(ListTile(title: Text("磁盘信息(${_partitions.length})")));
    for (var i = 0; i < _partitions.length; i++) {
      var e = _partitions[i];
      children.add(
        ListTile(
          title: Text(
              "挂载点：${e.path}  文件系统：${e.fstype}  容量：${formatBytes(e.used, 2)}/${formatBytes(e.total, 2)}"),
          subtitle: LinearProgressIndicator(
            value: e.usedPercent / 100,
          ),
        ),
      );
    }
    return SizedBox(
      height: 250,
      child: Card(
        child: ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: children,
        ),
      ),
    );
  }

  Widget getUserCard() {
    List<Widget> children = [];
    children.add(ListTile(title: Text("用户信息(${_users.length})")));
    for (var i = 0; i < _users.length; i++) {
      var e = _users[i];
      children.add(
        ListTile(
          title: Text(
              "用户：${e.name} 登录时间：${humanizerDatetime(DateTime.fromMillisecondsSinceEpoch(e.started * 1000), withRemain: true)}"),
          subtitle: Text("终端：${e.terminal}     主机：${e.host}"),
        ),
      );
    }
    return SizedBox(
      height: 56.0 * children.length + 12,
      child: Card(
        child: ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: children,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProgressDialog(
        loading: _loading,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: ListView.builder(
            itemBuilder: onItemBuilder,
          ),
        ));
  }
}
