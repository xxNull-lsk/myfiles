

import 'package:flutter/material.dart';

class ServerProcessInfo extends StatefulWidget {
  const ServerProcessInfo({super.key});

  @override
  State<ServerProcessInfo> createState() => _ServerProcessInfoState();
}

class _ServerProcessInfoState extends State<ServerProcessInfo> {
  @override
  Widget build(BuildContext context) {
    return Container(child: Text("进程信息"),);
  }
}