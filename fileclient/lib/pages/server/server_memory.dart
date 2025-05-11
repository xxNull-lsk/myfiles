import 'dart:async';
import 'dart:math';

import 'package:fileclient/pages/server/types.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fluttericon/entypo_icons.dart';

import '../../backend/backend.dart';
import '../../util.dart';

class ServerMemoryInfo extends StatefulWidget {
  const ServerMemoryInfo({super.key});

  @override
  State<ServerMemoryInfo> createState() => _ServerMemoryInfoState();
}

class _ServerMemoryInfoState extends State<ServerMemoryInfo> {
  var valStyle = TextStyle(
    fontSize: 16,
    color: Colors.blueGrey,
    fontFamily: "NotoSansMono",
  );

  var keyStyle = TextStyle(
    fontSize: 16,
    fontFamily: "NotoSansMono",
  );
  final List<MemoryStateInfo> _memories = [];
  Timer? _timer;
  @override
  void initState() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) {
        return;
      }
      Backend.getServerMemoryInfo(
          (res) => (!mounted)
              ? null
              : setState(() {
                  onServerMemoryInfoSucceed(res);
                }),
          onFailed);
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      Backend.getServerMemoryInfo(onServerMemoryInfoSucceed, onFailed);
    });

    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void onServerMemoryInfoSucceed(Map info) {
    _memories.clear();
    for (var i = 0; i < info["data"].length; i++) {
      _memories.add(MemoryStateInfo.fromJson(info["data"][i]));
    }
    if (mounted) {
      setState(() {});
    }
  }

  Widget buildChart(
      int totalBytes, double maxX, List<FlSpot> spots, DateTime startDatetime,
      {String titleChart = "", Color lineColor = Colors.blue}) {
    return AspectRatio(
      aspectRatio: 1.2,
      child: LineChart(
        duration: Duration(seconds: 0),
        LineChartData(
          maxY: 100,
          minY: 0,
          maxX: maxX,
          minX: 0,
          lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                var values = touchedBarSpots.map((barSpot) {
                  DateFormat formatter = DateFormat("HH:mm:ss");
                  String timeSpot = formatter.format(startDatetime
                      .add(Duration(seconds: barSpot.x.toInt()))
                      .toLocal());
                  return LineTooltipItem(
                    '$timeSpot\n${barSpot.y.toStringAsFixed(1)}%\n${formatBytes((barSpot.y * totalBytes / 100).toInt(), 1)}',
                    TextStyle(
                      color: Colors.blue,
                      fontSize: 16,
                      fontFamily: "NotoSansMono",
                    ),
                  );
                }).toList();
                return values;
              })),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: 20,
                getTitlesWidget: (value, meta) {
                  if (value == 0 || value == 100) {
                    return Container();
                  }
                  return Text("${value.toStringAsFixed(0)}%");
                },
              ),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: maxX.toDouble(),
                getTitlesWidget: (value, meta) {
                  if (value == 0) {
                    return Text(
                      titleChart,
                      style: keyStyle,
                    );
                  }
                  return Text("100%");
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
                    return Text("0");
                  }
                  return Text("${value.toStringAsFixed(0)}秒");
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
            horizontalInterval: 2,
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
              spots: spots,
              isCurved: true,
              color: lineColor,
              barWidth: 2,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget getMemoryPercentItem() {
    List<FlSpot> spots = [];
    double maxX = 0;
    int totalBytes = 0;
    DateTime startDatetime = DateTime.now();
    if (_memories.isNotEmpty) {
      startDatetime = _memories.first.time;
      for (var info in _memories) {
        double x = info.time.difference(startDatetime).inSeconds.toDouble();
        double y = info.stat.used * 100 / info.stat.total;
        totalBytes = info.stat.total;
        spots.insert(0, FlSpot(x, y));
        maxX = max(maxX, x);
      }
    }
    return buildChart(totalBytes, maxX > 0 ? maxX : 100, spots, startDatetime,
        titleChart: "物理");
  }

  Widget getSwapPercentItem() {
    List<FlSpot> spots = [];
    double maxX = 0;
    DateTime startDatetime = DateTime.now();
    int totalBytes = 0;
    if (_memories.isNotEmpty) {
      startDatetime = _memories.first.time;
      for (var info in _memories) {
        double x = info.time.difference(startDatetime).inSeconds.toDouble();
        double y = info.stat.swapused * 100 / info.stat.swaptotal;
        totalBytes = info.stat.swaptotal;
        spots.insert(0, FlSpot(x, y));
        maxX = max(maxX, x);
      }
    }
    return buildChart(totalBytes, maxX > 0 ? maxX : 100, spots, startDatetime,
        titleChart: "虚拟", lineColor: Colors.orange);
  }

  Widget getMemoryInfoList() {
    ServerMemory mem = ServerMemory.fromMap({});
    if (_memories.isNotEmpty) {
      mem = _memories.last.stat;
    }
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Text("内存总量", style: keyStyle),
            title: Text(formatBytes(mem.total, 1), style: valStyle),
          ),
          ListTile(
            leading: Text("已用内存", style: keyStyle),
            title: Text(formatBytes(mem.used, 1), style: valStyle),
          ),
          ListTile(
            leading: Text("可用内存", style: keyStyle),
            title: Text(formatBytes(mem.free, 1), style: valStyle),
          ),
          ListTile(
            leading: Text("虚拟内存", style: keyStyle),
            title: Text(formatBytes(mem.swaptotal, 1), style: valStyle),
          ),
          ListTile(
            leading: Text("已用虚拟内存", style: keyStyle),
            title: Text(formatBytes(mem.swapused, 1), style: valStyle),
          ),
          ListTile(
            leading: Text("可用虚拟内存", style: keyStyle),
            title: Text(formatBytes(mem.swaptotal - mem.swapused, 1),
                style: valStyle),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_memories.isEmpty) {
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
                leading: const Text("内存", style: TextStyle(fontSize: 32)),
                subtitle: Text(formatBytes(_memories.first.stat.total, 1),
                    style: TextStyle(
                        color: Colors.grey, fontFamily: "NotoSansMono")),
              ),
              const Divider(),
              Padding(
                padding: EdgeInsets.fromLTRB(36, 0, 24, 0),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Entypo.dot,
                          color: Colors.blue,
                        ),
                        const Text("物理内存"),
                        SizedBox(width: 16),
                        Icon(
                          Entypo.dot,
                          color: Colors.orange,
                        ),
                        const Text("虚拟内存"),
                        const Spacer(),
                      ],
                    ),
                    SizedBox(
                      height: 360,
                      child: getMemoryPercentItem(),
                    ),
                    SizedBox(
                      height: 360,
                      child: getSwapPercentItem(),
                    )
                  ],
                ),
              ),
              getMemoryInfoList(),
            ],
          ),
        ));
  }
}
