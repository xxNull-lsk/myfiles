import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../backend/backend.dart';
import '../../util.dart';
import 'types.dart';
import 'package:fluttericon/elusive_icons.dart';
import 'package:fluttericon/font_awesome5_icons.dart';

class ServerCpuInfo extends StatefulWidget {
  const ServerCpuInfo({super.key});

  @override
  State<ServerCpuInfo> createState() => _ServerCpuInfoState();
}

class _ServerCpuInfoState extends State<ServerCpuInfo> {
  ServerCpu _cpu = ServerCpu.fromMap({});
  bool _showCoreChart = false;
  Timer? _timer;
  @override
  void initState() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) {
        return;
      }
      Backend.getServerCpuInfo(
          (res) => (!mounted)
              ? null
              : setState(() {
                  onServerCpuInfoSucceed(res);
                }),
          onFailed);
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      Backend.getServerCpuInfo(onServerCpuInfoSucceed, onFailed);
    });

    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void onServerCpuInfoSucceed(Map info) {
    _cpu = ServerCpu.fromMap(info["data"]);
    if (mounted) {
      setState(() {});
    }
  }

  var valStyle = TextStyle(
    fontSize: 16,
    color: Colors.blueGrey,
    fontFamily: "NotoSansMono",
  );

  var keyStyle = TextStyle(
    fontSize: 16,
    fontFamily: "NotoSansMono",
  );

  Widget getCpuPercentItem() {
    List<FlSpot> spots = [];
    double maxX = 0;
    DateTime startDatetime = DateTime.now();
    if (_cpu.cpuStateInfo.isNotEmpty) {
      startDatetime = _cpu.cpuStateInfo.first.time;
      for (var info in _cpu.cpuStateInfo) {
        double x = info.time.difference(startDatetime).inSeconds.toDouble();
        double y = info.stat.totalPercent.last;
        spots.insert(0, FlSpot(x, y));
        maxX = max(maxX, x);
      }
    }
    return buildCpuChart(maxX, spots, startDatetime, titleChart: "CPU");
  }

  List<Widget> getCorePercentItem() {
    List<List<FlSpot>> cureSpots = [];
    double maxX = 0;
    DateTime startDatetime = DateTime.now();
    if (_cpu.cpuStateInfo.isNotEmpty) {
      startDatetime = _cpu.cpuStateInfo.first.time;
      for (var info in _cpu.cpuStateInfo) {
        double x = info.time.difference(startDatetime).inSeconds.toDouble();
        for (var i = 0; i < info.stat.perPercents.length; i++) {
          if (cureSpots.length <= i) {
            cureSpots.add([]);
          }
          double y = info.stat.perPercents[i];
          cureSpots[i].insert(0, FlSpot(x, y));
          maxX = max(maxX, x);
        }
      }
    }
    List<Widget> items = [];
    for (var i = 0; i < cureSpots.length; i++) {
      items.add(SizedBox(
          width: 320,
          height: 256,
          child: buildCpuChart(maxX, cureSpots[i], startDatetime,
              titleChart: "CPU$i")));
    }
    return items;
  }

  Widget buildCpuChart(double maxX, List<FlSpot> spots, DateTime startDatetime,
      {String titleChart = ""}) {
    return AspectRatio(
      aspectRatio: 1.7,
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
                    '$timeSpot ${barSpot.y.toStringAsFixed(1)}%',
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
              color: Colors.blue,
              barWidth: 2,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget getCpuInfoList() {
    CpuBaseInfo cpu = CpuBaseInfo.fromJson({});
    if (_cpu.cpuInfos.isNotEmpty) {
      cpu = _cpu.cpuInfos.last;
    }
    double cpuPercent = 0;
    if (_cpu.cpuStateInfo.isNotEmpty) {
      cpuPercent = _cpu.cpuStateInfo.last.stat.totalPercent.last;
    }
    String temperature = "";
    if (_cpu.cpuStateInfo.isNotEmpty) {
      temperature += "${_cpu.cpuStateInfo.last.stat.temperature}℃";
      String coreTemperature = "";
      for (var element in _cpu.cpuStateInfo.last.stat.preTemperatures) {
        if (coreTemperature.isNotEmpty) {
          coreTemperature += " ";
        }
        coreTemperature += "$element℃";
      }
      if (coreTemperature.isNotEmpty) {
        temperature += "($coreTemperature)";
      }
    }
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Elusive.record),
              SizedBox(width: 4),
              Text("频率值", style: keyStyle)
            ]),
            title: Text("${cpu.mhz} MHz", style: valStyle),
          ),
          ListTile(
            leading: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Elusive.tasks),
              SizedBox(width: 4),
              Text("核心数", style: keyStyle)
            ]),
            title: Text("${_cpu.physicalCount}/${_cpu.logicalCount}",
                style: valStyle),
          ),
          ListTile(
            leading: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Elusive.chart),
              SizedBox(width: 4),
              Text("使用率", style: keyStyle)
            ]),
            title: Text("${cpuPercent.toStringAsFixed(1)}%", style: valStyle),
          ),
          ListTile(
            leading: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Elusive.chart),
              SizedBox(width: 4),
              Text("温度", style: keyStyle)
            ]),
            title: Text(temperature, style: valStyle),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cpu.cpuInfos.isEmpty) {
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
                  leading: const Text("处理器", style: TextStyle(fontSize: 32)),
                  subtitle: Text(_cpu.cpuInfos.last.modelName,
                      style: TextStyle(
                          color: Colors.grey, fontFamily: "NotoSansMono")),
                  trailing: IconButton(
                    onPressed: () => setState(() {
                      _showCoreChart = !_showCoreChart;
                    }),
                    icon: Icon(FontAwesome5.exchange_alt),
                    splashRadius: 24,
                  ),
                ),
                const Divider(),
                Visibility(
                  visible: !_showCoreChart,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, 0),
                    child: SizedBox(
                      height: 480,
                      child: getCpuPercentItem(),
                    ),
                  ),
                ),
                Visibility(
                  visible: _showCoreChart,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, 0),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 24,
                      children: getCorePercentItem(),
                    ),
                  ),
                ),
                const Divider(),
                getCpuInfoList(),
              ]),
        ));
  }
}
