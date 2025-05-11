import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../backend/backend.dart';
import '../../global.dart';
import '../../util.dart';
import '../../pages/util/desktop_check.dart'
    if (dart.library.html) '../../pages/util/web_check.dart';
import '../server/types.dart';

class ServerBaseInfo extends StatefulWidget {
  const ServerBaseInfo({super.key});

  @override
  State<ServerBaseInfo> createState() => _ServerBaseInfoState();
}

class _ServerBaseInfoState extends State<ServerBaseInfo> {
  var valStyle = TextStyle(
    color: Colors.blueGrey,
    fontFamily: "NotoSansMono",
  );
  ServerOs _os = ServerOs.fromMap({});
  ServerCpu _cpu = ServerCpu.fromMap({});
  ServerMemory _memory = ServerMemory.fromMap({});
  ServerNetWork _network = ServerNetWork.fromMap({});
  ServerDisks _disk = ServerDisks.fromJson({});
  final List<ServerUser> _users = [];
  Timer? _timer;
  @override
  void initState() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) {
        return;
      }
      Backend.getServerInfo(
          (res) => (!mounted)
              ? null
              : setState(() {
                  onServerInfoSucceed(res);
                }),
          onFailed,
          false,
          "1s");
    });

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      Backend.getServerInfo(onServerInfoSucceed, onFailed, true, "1s");
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
    _network = ServerNetWork.fromMap(info["network"]);

    _memory = ServerMemory.fromMap(info["memory"]);
    _disk = ServerDisks.fromJson(info["disk"]);
    _users.clear();
    for (var element in info["users"]) {
      _users.add(ServerUser.fromMap(element));
    }
    if (mounted) {
      setState(() {});
    }
  }

  Widget getCpuInfo() {
    double percent = 0.0;
    if (_cpu.cpuStateInfo.isNotEmpty) {
      percent = _cpu.cpuStateInfo.last.stat.totalPercent
              .reduce((value, element) => value + element) /
          _cpu.cpuStateInfo.last.stat.totalPercent.length;
    }
    return Row(
      children: [
        Column(children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Text(
                "${percent.toStringAsFixed(1)}%",
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.bold),
              ),
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  strokeWidth: 12,
                  backgroundColor: Colors.grey[300],
                  value: percent / 100,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text("CPU",
              style: TextStyle(
                fontFamily: "NotoSansMono",
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
                fontSize: 16,
              ))
        ])
      ],
    );
  }

  Widget getMemoryInfo() {
    var e = _memory.used * 100 / _memory.total;
    return Column(children: [
      Stack(
        alignment: Alignment.center,
        children: [
          Text(
            formatBytes(_memory.used, 1),
            style: TextStyle(
                fontSize: 13,
                color: Colors.blueGrey,
                fontWeight: FontWeight.bold),
          ),
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              strokeWidth: 12,
              backgroundColor: Colors.grey[300],
              value: e / 100,
            ),
          ),
        ],
      ),
      SizedBox(height: 12),
      Text(
        "内存",
        style: TextStyle(
          fontFamily: "NotoSansMono",
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
          fontSize: 16,
        ),
      )
    ]);
  }

  Widget buildCard(String title, List<Widget> child) {
    return SizedBox(
      width: 182,
      height: 118,
      child: Card(
        color: Colors.grey[100],
        child: Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(
                    Icons.memory,
                    size: 24,
                  ),
                  Text(
                    title,
                    style: TextStyle(
                        fontFamily: "NotoSansMono",
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ]),
                SizedBox(height: 16),
                ...child
              ],
            )),
      ),
    );
  }

  Widget getMemoryCard() {
    String used = formatBytes(_memory.used, 1, fixWidth: true);
    String total = formatBytes(_memory.total, 1, fixWidth: true);
    return buildCard("内存", [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("总计: $total", style: valStyle),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("已用: $used", style: valStyle),
        ],
      )
    ]);
  }

  Widget getNetworkCard() {
    double send = 0;
    double recv = 0;
    for (ServerInterface item in _network.interfaces.values) {
      if (!item.flags.contains("up") ||
          item.flags.contains("loopback") ||
          item.flags.contains("virtual")) {
        continue;
      }
      if (item.speedRecv.isEmpty) {
        continue;
      }
      recv += item.speedRecv.last;
      send += item.speedSend.last;
    }
    String r = formatBytes(send.toInt(), 1, fixWidth: true);
    String s = formatBytes(recv.toInt(), 1, fixWidth: true);
    // 补齐长度
    if (r.length < s.length) {
      r = r.padLeft(s.length, " ");
    }
    if (s.length < r.length) {
      s = s.padLeft(r.length, " ");
    }
    return buildCard(
      "网络",
      [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("接收: $r/S", style: valStyle),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("发送: $s/S", style: valStyle),
          ],
        )
      ],
    );
  }

  Widget getDiskCard() {
    double write = 0;
    double read = 0;
    for (var element in _disk.blocks.values) {
      if (element.stateInfo == null || element.stateInfo!.isEmpty) {
        continue;
      }
      write += element.stateInfo!.last.stat!.writeSpeed;
      read += element.stateInfo!.last.stat!.readSpeed;
    }
    String w = formatBytes(write.toInt(), 1, fixWidth: true);
    String r = formatBytes(read.toInt(), 1, fixWidth: true);
    // 补齐长度
    if (r.length < w.length) {
      r = r.padLeft(w.length, " ");
    }
    if (w.length < r.length) {
      w = w.padLeft(r.length, " ");
    }
    return buildCard("硬盘", [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("读取: $r/S", style: valStyle),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("写入: $w/S", style: valStyle),
        ],
      )
    ]);
  }

  Widget getTemperatureCard() {
    int temperature = 0;
    if (_cpu.cpuStateInfo.isNotEmpty) {
      temperature = _cpu.cpuStateInfo.last.stat.temperature;
    }
    return buildCard("温度", [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
              "CPU: ${temperature.toString()}°C",
              style: valStyle),
        ],
      ),
    ]);
  }

  Widget getServerInfoList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            ListTile(
              title: Text("服务器信息",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                      fontFamily: "NotoSansMono")),
            ),
            ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Icon(Icons.folder), Text("系统名称")],
                  ),
                  title: Text(
                    Global.serverVersion.name,
                    style: valStyle,
                  ),
                ),
                ListTile(
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Icon(Icons.list), Text("系统版本")],
                  ),
                  title: Text(
                    Global.serverVersion.version,
                    style: valStyle,
                  ),
                ),
                ListTile(
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Icon(Icons.timer), Text("编译时间")],
                  ),
                  title: Text(
                    Global.serverVersion.time,
                    style: valStyle,
                  ),
                ),
                ListTile(
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Icon(Icons.code), Text("代码版本")],
                  ),
                  title: Text(
                    Global.serverVersion.commit,
                    style: valStyle,
                  ),
                ),
                Global.serverVersion.url.isEmpty
                    ? Container()
                    : ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [Icon(Icons.link), Text("系统网址")],
                        ),
                        title: MouseRegion(
                          cursor: SystemMouseCursors.click, // 设置鼠标悬停时光标为手型
                          child: GestureDetector(
                              onTap: () =>
                                  openUrl(Global.serverVersion.url, true),
                              child: Text(Global.serverVersion.url,
                                  style: TextStyle(
                                    color: Colors.blue,
                                  ))),
                        ),
                      ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget getOSInfoList() {
    DateFormat formatter = DateFormat("yyyy-MM-dd HH:mm:ss");
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text("操作系统信息",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                    fontFamily: "NotoSansMono")),
          ),
          ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(Icons.timer), Text("启动时间")],
            ),
            title: Tooltip(
              message: formatter.format(_os.bootTime),
              child: Text(
                humanizerDatetime(_os.bootTime, withRemain: true),
                style: valStyle,
              ),
            ),
          ),
          ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(Icons.computer), Text("操作系统")],
            ),
            title: Text("${_os.family} ${_os.version}", style: valStyle),
          ),
          ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(Icons.key), Text("系统内核")],
            ),
            title:
                Text("${_os.kernelArch} ${_os.kernelVersion}", style: valStyle),
          ),
          ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(Icons.visibility), Text("虚拟状态")],
            ),
            title: Text("${_os.virtualizationSystem} ${_os.virtualizationRole}",
                style: valStyle),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.all(8),
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [getCpuInfo(), getMemoryInfo()],
              ),
              SizedBox(height: 24),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  getMemoryCard(),
                  getNetworkCard(),
                  getDiskCard(),
                  getTemperatureCard()
                ],
              ),
              SizedBox(height: 24),
              getOSInfoList(),
              SizedBox(height: 24),
              getServerInfoList(),
            ],
          ),
        ));
  }
}
