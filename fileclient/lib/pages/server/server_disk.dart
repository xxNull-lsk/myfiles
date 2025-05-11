import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/entypo_icons.dart';

import '../../backend/backend.dart';
import '../../util.dart';
import 'types.dart';

class ServerDiskInfo extends StatefulWidget {
  const ServerDiskInfo({super.key});

  @override
  State<ServerDiskInfo> createState() => _ServerDiskInfoState();
}

class _ServerDiskInfoState extends State<ServerDiskInfo> {
  ServerDisks _disk = ServerDisks.fromJson({});
  Timer? _timer;
  final Color _colorWrite = Colors.orange;
  final Color _colorRead = Colors.blue;
  String currentIndex = "";

  var valStyle = TextStyle(
    fontSize: 16,
    color: Colors.blueGrey,
    fontFamily: "NotoSansMono",
  );

  @override
  void initState() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) {
        return;
      }
      Backend.getServerDiskInfo(onServerInfoSucceed, onFailed);
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      Backend.getServerDiskInfo(onServerInfoSucceed, onFailed);
    });

    super.initState();
  }

  void onServerInfoSucceed(Map info) {
    _disk = ServerDisks.fromJson(info["data"]);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  TextStyle keyStyle({Color? color}) {
    return TextStyle(fontSize: 16, fontFamily: "NotoSansMono", color: color);
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
                      ? _colorRead
                      : _colorWrite; // 这里可以根据barIndex来判断是哪个数据集
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

  List<Widget> getStatusItem() {
    if (_disk.blocks.isEmpty) {
      return [];
    }
    List<Widget> items = [];
    for (var block in _disk.blocks.values) {
      List<FlSpot> spotsRead = [];
      List<FlSpot> spotsWrite = [];
      double maxY = 0;
      int maxX = 1;
      if (block.stateInfo == null || block.stateInfo!.isEmpty) {
        continue;
      }
      maxX = block.stateInfo!.length;
      for (var x = 0; x < maxX; x++) {
        var stateInfo = block.stateInfo![x];
        double y = stateInfo.stat!.readSpeed;
        maxY = max(maxY, y);
        spotsRead.insert(0, FlSpot(x.toDouble(), y));
        y = stateInfo.stat!.writeSpeed;
        maxY = max(maxY, y);
        spotsWrite.insert(0, FlSpot(x.toDouble(), y));
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
                      maxX.toDouble(), maxY, spotsRead, spotsWrite,
                      titleChart:
                          "${block.name} - ${formatDiskBytes(block.size ?? 0, 1)}",
                      colorRecv: _colorRead,
                      colorSend: _colorWrite,
                      colorText: currentIndex == block.name
                          ? Colors.blue
                          : Colors.black))),
          onTap: () {
            currentIndex = block.name;
            setState(() {});
          }));
    }
    return items;
  }

  Widget getBlockInfo() {
    if (currentIndex.isEmpty) {
      for (var block in _disk.blocks.values) {
        currentIndex = block.name;
        break;
      }
    }
    BlockDevice block = _disk.blocks[currentIndex]!;
    IOCountersStat ioCountersStat = _disk.counters[currentIndex]!;

    List<Widget> partitions = [];
    if (block.children != null && block.children!.isNotEmpty) {
      for (var partition in block.children!) {
        Card card = Card(
            color: Colors.grey[100],
            child: Column(children: [
              ListTile(
                leading: Text("分区名称", style: keyStyle()),
                title: Text(partition.name, style: valStyle),
              ),
              ListTile(
                leading: Text("文件系统", style: keyStyle()),
                title: Text(partition.fstype ?? "", style: valStyle),
              ),
              ListTile(
                leading: Text("uuid", style: keyStyle()),
                title: Text(partition.uuid ?? "", style: valStyle),
              ),
              ListTile(
                leading: Text("挂载路径", style: keyStyle()),
                title: Text(partition.mountpoints.join(", "), style: valStyle),
              ),
              ListTile(
                leading: Text("分区容量", style: keyStyle()),
                title: Text(formatDiskBytes(partition.size ?? 0, 1),
                    style: valStyle),
              ),
              partition.fsused != null
                  ? ListTile(
                      leading: Text("已用比例", style: keyStyle()),
                      title: Text(partition.fsused ?? "", style: valStyle),
                    )
                  : Container(),
              partition.fsavail != null
                  ? ListTile(
                      leading: Text("可用空间", style: keyStyle()),
                      title: Text(formatBytes(partition.fsavail ?? 0, 1),
                          style: valStyle),
                    )
                  : Container(),
            ]));
        partitions.add(SizedBox(
          width: 480,
          child: card,
        ));
      }
    }

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Text("设备名称", style: keyStyle()),
            title: Text(block.name, style: valStyle),
          ),
          block.label != null
              ? ListTile(
                  leading: Text("设备标签", style: keyStyle()),
                  title: Text(block.label ?? "", style: valStyle),
                )
              : Container(),
          ListTile(
            leading: Text("设备容量", style: keyStyle()),
            title: Text(formatDiskBytes(block.size ?? 0, 1), style: valStyle),
          ),
          block.mountpoints.isNotEmpty && block.mountpoints.first!.isNotEmpty
              ? ListTile(
                  leading: Text("挂载路径", style: keyStyle()),
                  title: Text(block.mountpoints.join(", "), style: valStyle),
                )
              : Container(),
          block.fstype != null
              ? ListTile(
                  leading: Text("文件系统", style: keyStyle()),
                  title: Text(block.fstype ?? "", style: valStyle),
                )
              : Container(),
          block.fsused != null
              ? ListTile(
                  leading: Text("可用空间", style: keyStyle()),
                  title:
                      Text(formatBytes(block.fsavail ?? 0, 1), style: valStyle),
                )
              : Container(),
          block.fsused != null
              ? ListTile(
                  leading: Text("已用比例", style: keyStyle()),
                  title: Text(block.fsused ?? "", style: valStyle),
                )
              : Container(),
          block.uuid != null
              ? ListTile(
                  leading: Text("唯一ID", style: keyStyle()),
                  title: Text(block.uuid ?? "", style: valStyle),
                )
              : Container(),
          block.children != null
              ? ListTile(
                  leading: Text("分区数量", style: keyStyle()),
                  title:
                      Text(block.children!.length.toString(), style: valStyle),
                )
              : Container(),
          ListTile(
            leading: Text("读取大小", style: keyStyle()),
            title:
                Text(formatBytes(ioCountersStat.readBytes, 1), style: valStyle),
          ),
          ListTile(
            leading: Text("写入大小", style: keyStyle()),
            title: Text(formatBytes(ioCountersStat.writeBytes, 1),
                style: valStyle),
          ),
          ListTile(
            leading: Text("读取次数", style: keyStyle()),
            title: Text(
                "${ioCountersStat.mergedReadCount.toString()}(${ioCountersStat.readCount.toString()})",
                style: valStyle),
          ),
          ListTile(
            leading: Text("写入次数", style: keyStyle()),
            title: Text(
                "${ioCountersStat.mergedWriteCount.toString()}(${ioCountersStat.writeCount.toString()})",
                style: valStyle),
          ),
          ListTile(
            leading: Text("平均读取速度", style: keyStyle()),
            title: Text(
                "${formatBytes((ioCountersStat.readBytes / ioCountersStat.readTime * 1000).toInt(), 1)}/S",
                style: valStyle),
          ),
          ListTile(
            leading: Text("平均写入速度", style: keyStyle()),
            title: Text(
                "${formatBytes((ioCountersStat.writeBytes / ioCountersStat.writeTime * 1000).toInt(), 1)}/S",
                style: valStyle),
          ),
          Wrap(spacing: 24, runSpacing: 24, children: partitions)
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_disk.blocks.isEmpty) {
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
              leading: const Text("磁盘", style: TextStyle(fontSize: 32)),
            ),
            const Divider(),
            Row(
              children: [
                Icon(
                  Entypo.dot,
                  color: _colorRead,
                ),
                const Text("读取速度"),
                SizedBox(width: 16),
                Icon(
                  Entypo.dot,
                  color: _colorWrite,
                ),
                const Text("写入速度"),
                const Spacer(),
              ],
            ),
            Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: getStatusItem(),
                )),
            getBlockInfo(),
          ])),
    );
  }
}
