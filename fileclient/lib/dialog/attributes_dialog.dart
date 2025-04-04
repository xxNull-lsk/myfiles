import 'package:fileclient/util.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../file_types.dart';

// TODO: 支持查看多个文件的属性
// TODO: 支持计算MD5、SHA1、SHA256、SHA512等信息
// 支持统计文件夹的文件数量、大小等信息
class AttributesDialog extends StatefulWidget {
  const AttributesDialog(
      {super.key,
      required this.filePath,
      required this.attributes,
      this.title = "属性"});
  final String title;
  final String filePath;
  final FileAttributes attributes;

  @override
  AttributesDialogState createState() => AttributesDialogState();
}

class AttributesDialogState extends State<AttributesDialog> {
  @override
  Widget build(BuildContext context) {
    DateFormat dateFormat = DateFormat("yyyy-MM-dd HH:mm:ss");
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Text("名称"),
            title: Text(widget.attributes.entry.name),
          ),
          ListTile(
            leading: const Text("位置"),
            title: Text(widget.filePath),
          ),
          widget.attributes.entry.isDir
              ? Container()
              : ListTile(
                  leading: const Text("大小"),
                  title: Text(
                      "${formatBytes(widget.attributes.entry.size, 2)}(${widget.attributes.entry.size.toString()})"),
                ),
          ListTile(
            leading: const Text("修改时间"),
            title: Text(dateFormat.format(widget.attributes.entry.modifiedAt)),
          ),
          ListTile(
            leading: const Text("创建时间"),
            title: Text(dateFormat.format(widget.attributes.entry.createdAt)),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
