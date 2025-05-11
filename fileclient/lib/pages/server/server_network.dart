import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/entypo_icons.dart';

import '../../backend/backend.dart';
import '../../util.dart';
import 'types.dart';

class ServerNetworkInfo extends StatefulWidget {
  const ServerNetworkInfo({super.key});

  @override
  State<ServerNetworkInfo> createState() => _ServerNetworkInfoState();
}

class _ServerNetworkInfoState extends State<ServerNetworkInfo> {
  String currentIndex = "";
  bool _showVritualInterface = false;
  var valStyle = TextStyle(
    fontSize: 16,
    color: Colors.blueGrey,
    fontFamily: "NotoSansMono",
  );
  TextStyle keyStyle({Color? color}) {
    return TextStyle(fontSize: 16, fontFamily: "NotoSansMono", color: color);
  }

  ServerNetWork _netWork = ServerNetWork.fromMap({});
  Timer? _timer;
  final Color _colorSend = Colors.orange;
  final Color _colorRecv = Colors.blue;
  @override
  void initState() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) {
        return;
      }
      Backend.getServerNetworkInfo(
          (res) => (!mounted)
              ? null
              : setState(() {
                  onServerNetworkInfoSucceed(res);
                }),
          onFailed);
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      Backend.getServerNetworkInfo(onServerNetworkInfoSucceed, onFailed);
    });

    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void onServerNetworkInfoSucceed(Map info) {
    _netWork = ServerNetWork.fromMap(info["data"]);
    if (mounted) {
      setState(() {});
    }
  }

  List<Widget> getNetworkItems() {
    List<Widget> items = [];
    int maxX = 1;
    for (var interface in _netWork.interfaces.values) {
      if ((interface.flags.contains("virtual") && !_showVritualInterface) ||
          !interface.flags.contains("up")) {
        continue;
      }
      List<FlSpot> spotsRecv = [];
      List<FlSpot> spotsSend = [];
      double maxY = 0;
      maxX = interface.speedRecv.length;
      for (var index = 0; index < maxX; index++) {
        spotsRecv
            .add(FlSpot(index.toDouble(), interface.speedRecv[index].abs()));
        spotsSend
            .add(FlSpot(index.toDouble(), interface.speedSend[index].abs()));
        maxY = max(maxY, interface.speedRecv[index].abs());
        maxY = max(maxY, interface.speedSend[index].abs());
      }
      if (maxY == 0) {
        maxY = 1;
      }
      maxY *= 1.1;
      items.add(GestureDetector(
          child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                  height: 256,
                  child: buildChart(
                      maxX.toDouble(), maxY, spotsRecv, spotsSend,
                      titleChart: interface.name,
                      colorRecv: _colorRecv,
                      colorSend: _colorSend,
                      colorText: currentIndex == interface.name
                          ? Colors.blue
                          : Colors.black))),
          onTap: () {
            currentIndex = interface.name;
            setState(() {});
          }));
    }
    return items;
  }

  double getTextWidth(String txt, {TextStyle? style}) {
    final textPainter = TextPainter(
      text: TextSpan(text: txt, style: style ?? keyStyle()),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(); // 计算文本的布局
    return textPainter.width;
  }

  Widget buildChart(
      double maxX, double maxY, List<FlSpot> spotsRecv, List<FlSpot> spotsSend,
      {String titleChart = "",
      Color colorRecv = Colors.blue,
      Color colorSend = Colors.orange,
      Color colorText = Colors.black}) {
    return AspectRatio(
      aspectRatio: 1.2,
      child: LineChart(
        duration: Duration(seconds: 0),
        LineChartData(
          maxY: maxY,
          minY: 0,
          maxX: maxX,
          minX: 0,
          lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                var values = touchedBarSpots.map((barSpot) {
                  Color color = barSpot.barIndex == 0
                      ? _colorRecv
                      : _colorSend; // 这里可以根据barIndex来判断是哪个数据集
                  return LineTooltipItem(
                    '${formatBytes(barSpot.y.toInt(), 1)}/S',
                    TextStyle(
                      color: color,
                      fontSize: 16,
                      fontFamily: "NotoSansMono",
                    ),
                  );
                }).toList();
                return values;
              })),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: maxX.toDouble(),
                getTitlesWidget: (value, meta) {
                  if (value == 0) {
                    final width = getTextWidth(titleChart) * 2; // 获取文本宽度
                    return SizedBox(
                        width: width,
                        child: Text(
                          titleChart,
                          textAlign: TextAlign.right,
                          style: keyStyle(color: colorText),
                        ));
                  }
                  final String txt = "${formatBytes(maxY.toInt(), 1)}/S";
                  final width = getTextWidth(txt) * 2; // 获取文本宽度
                  return SizedBox(
                      width: width,
                      child: Text(
                        txt,
                        textAlign: TextAlign.left,
                        style: keyStyle(color: colorText),
                      ));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: maxX.toDouble(),
                getTitlesWidget: (value, meta) {
                  value = meta.max - value;
                  if (value == 0) {
                    final String txt = "0";
                    final width = getTextWidth(txt) * 2; // 获取文本宽度
                    return SizedBox(
                        width: width,
                        child: Text(
                          txt,
                          textAlign: TextAlign.left,
                          style: keyStyle(color: colorText),
                        ));
                  }
                  final String txt = value.toStringAsFixed(0);
                  final width = getTextWidth(txt) * 2; // 获取文本宽度
                  return SizedBox(
                      width: width,
                      child: Text(
                        txt,
                        textAlign: TextAlign.right,
                        style: keyStyle(color: colorText),
                      ));
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: maxY / 50,
            verticalInterval: maxX / 50,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: const Color(0x2237434d),
                strokeWidth: 1,
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: const Color(0x2237434d),
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: const Color(0xff37434d), width: 1),
          ),
          lineBarsData: [
            LineChartBarData(
              preventCurveOverShooting: true,
              spots: spotsRecv,
              isCurved: true,
              color: colorRecv,
              barWidth: 2,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
            LineChartBarData(
              preventCurveOverShooting: true,
              spots: spotsSend,
              isCurved: true,
              color: colorSend,
              barWidth: 2,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget getNetworkItemList() {
    if (currentIndex.isEmpty) {
      for (var interface in _netWork.interfaces.values) {
        if (!interface.flags.contains("up")) {
          currentIndex = interface.name;
          break;
        }
        if ((interface.flags.contains("virtual") && !_showVritualInterface)) {
          continue;
        }
        currentIndex = interface.name;
        break;
      }
    }
    ServerInterface interface = _netWork.interfaces[currentIndex]!;
    ServerNetCounter netCounter = _netWork.counters[currentIndex]!;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Text("网卡名称", style: keyStyle()),
            title: Text(interface.name, style: valStyle),
          ),
          ListTile(
            leading: Text("物理地址", style: keyStyle()),
            title: Text(interface.hardwareaddr, style: valStyle),
          ),
          ListTile(
            leading: Text("网络地址", style: keyStyle()),
            title: Text(interface.addrs.join(', '), style: valStyle),
          ),
          ListTile(
            leading: Text("状态标志", style: keyStyle()),
            title: Text(interface.flags.join(", "), style: valStyle),
          ),
          ListTile(
            leading: Text("MTU", style: keyStyle()),
            title: Text(interface.mtu.toString(), style: valStyle),
          ),
          ListTile(
            leading: Text("接收速度", style: keyStyle()),
            title: Text("${formatBytes(interface.speedRecv.last.toInt(), 1)}/S",
                style: valStyle),
          ),
          ListTile(
            leading: Text("发送速度", style: keyStyle()),
            title: Text("${formatBytes(interface.speedSend.last.toInt(), 1)}/S",
                style: valStyle),
          ),
          ListTile(
            leading: Text("接收大小", style: keyStyle()),
            title: Text(formatBytes(netCounter.bytesRecv, 1), style: valStyle),
          ),
          ListTile(
            leading: Text("发送大小", style: keyStyle()),
            title: Text(formatBytes(netCounter.bytesSent, 1), style: valStyle),
          ),
          ListTile(
            leading: Text("接收包", style: keyStyle()),
            title: Text(netCounter.packetsRecv.toString(), style: valStyle),
          ),
          ListTile(
            leading: Text("发送包", style: keyStyle()),
            title: Text(netCounter.packetsSent.toString(), style: valStyle),
          ),
          ListTile(
            leading: Text("接收(丢弃包)", style: keyStyle()),
            title: Text(netCounter.dropin.toString(), style: valStyle),
          ),
          ListTile(
            leading: Text("发送(丢弃包)", style: keyStyle()),
            title: Text(netCounter.dropout.toString(), style: valStyle),
          ),
          ListTile(
            leading: Text("接收(错误包)", style: keyStyle()),
            title: Text(netCounter.errin.toString(), style: valStyle),
          ),
          ListTile(
            leading: Text("发送(错误包)", style: keyStyle()),
            title: Text(netCounter.errout.toString(), style: valStyle),
          ),
          ListTile(
            leading: Text("接收FIFO", style: keyStyle()),
            title: Text(netCounter.fifoin.toString(), style: valStyle),
          ),
          ListTile(
            leading: Text("发送FIFO", style: keyStyle()),
            title: Text(netCounter.fifoout.toString(), style: valStyle),
          ),
        ],
      ),
    );
  }

  void switchShowVirtualInterface() {
    _showVritualInterface = !_showVritualInterface;

    ServerInterface interface = _netWork.interfaces[currentIndex]!;
    if (interface.flags.contains("virtual") && !_showVritualInterface) {
      currentIndex = "";
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_netWork.interfaces.isEmpty) {
      return const Text("加载中...");
    }
    return Padding(
        padding: EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Text("网络", style: TextStyle(fontSize: 32)),
                  trailing: IconButton(
                    tooltip: "显示虚拟网卡",
                    splashRadius: 24,
                    icon: Icon(_showVritualInterface
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: switchShowVirtualInterface,
                  ),
                ),
                const Divider(),
                Row(
                  children: [
                    Icon(
                      Entypo.dot,
                      color: _colorRecv,
                    ),
                    const Text("接收速度"),
                    SizedBox(width: 16),
                    Icon(
                      Entypo.dot,
                      color: _colorSend,
                    ),
                    const Text("发送速度"),
                    const Spacer(),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 0),
                  child: Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: getNetworkItems()),
                ),
                getNetworkItemList(),
              ]),
        ));
  }
}
