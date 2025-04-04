import 'package:fileclient/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_picker_plus/flutter_picker_plus.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';

import '../util.dart';

class CreateSharedDialog extends StatefulWidget {
  const CreateSharedDialog({super.key, this.name = "", this.title = "新建分享"});
  final String title;
  final String name;

  @override
  CreateSharedDialogState createState() => CreateSharedDialogState();
}

class CreateSharedDialogState extends State<CreateSharedDialog> {
  void onFailed(Exception ex) {
    toastification.show(
      title: Text(ex.toString()),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  bool canDownload = true;
  bool canUpload = false;
  int maxCount = 0;
  int maxUploadSize = 0;
  int timeLimited = 0;
  String name = "";
  String code = "";

  @override
  void initState() {
    super.initState();
    code = generateRandomString(6);
    name = widget.name;
  }

  void onOK() {
    if (name.isEmpty) {
      toastification.show(
        title: const Text("分享名称不能为空"),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return;
    }
    SharedEntry entry = SharedEntry();
    entry.canDownload = canDownload;
    entry.canUpload = canUpload;
    entry.maxCount = maxCount;
    entry.maxUploadSize = maxUploadSize;
    entry.name = name;
    entry.code = code;
    entry.timeLimited = timeLimited;
    Navigator.of(context).pop(entry);
  }

  Future<int> pickNumber(
      String units, String title, int begin, int end, int jump) async {
    var picker = await Picker(
      adapter: NumberPickerAdapter(data: [
        NumberPickerColumn(
          begin: begin,
          end: end,
          jump: jump,
          onFormatValue: (value) => value == 0 ? "不限制" : value.toString(),
        ),
      ]),
      delimiter: [
        PickerDelimiter(
            child: Container(
          width: 30.0,
          alignment: Alignment.center,
          child: Text(units),
        ))
      ],
      hideHeader: true,
      title: Text(title),
    ).showDialog(context);
    if (picker != null) {
      return picker[0];
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    DateFormat dateFormatter = DateFormat('yyyy-MM-dd');
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: '分享名称',
            ),
            controller: TextEditingController(text: name),
            onChanged: (value) => name = value,
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: '分享码',
                  ),
                  controller: TextEditingController(text: code),
                  onChanged: (value) => code = value,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  code = generateRandomString(6);
                  setState(() {});
                },
              ),
            ],
          ),
          SwitchListTile(
            title: const Text('允许下载'),
            onChanged: (bool? value) {
              canDownload = value ?? false;
              setState(() {});
            },
            value: canDownload,
          ),
          SwitchListTile(
            title: const Text('允许上传'),
            onChanged: (bool? value) {
              canUpload = value ?? false;
              setState(() {});
            },
            value: canUpload,
          ),
          ListTile(
            title: const Text("最大访问次数"),
            trailing: Text(maxCount == 0 ? "不限制" : maxCount.toString()),
            onTap: () {
              pickNumber("次", "最大访问次数", 0, 500, 1).then((value) {
                if (value == -1) {
                  return;
                }
                maxCount = value;
                setState(() {});
              });
            },
          ),
          ListTile(
            title: const Text("最大上传大小"),
            trailing: Text(
                maxUploadSize == 0 ? "不限制" : "${maxUploadSize.toString()}MB"),
            onTap: () {
              pickNumber("MB", "最大上传大小", 0, 40960, 512).then((value) {
                if (value == -1) {
                  return;
                }
                maxUploadSize = value * 512;
                setState(() {});
              });
            },
          ),
          ListTile(
            title: const Text("限制天数"),
            trailing:
                Text(timeLimited == 0 ? "不限制" : "${timeLimited.toString()}天"),
            subtitle: Text(timeLimited == 0
                ? "永不过期"
                : "${dateFormatter.format(DateTime.now().add(Duration(days: timeLimited)))}过期"),
            onTap: () {
              pickNumber("天", "限制天数", 0, 365, 1).then((value) {
                if (value == -1) {
                  return;
                }
                timeLimited = value;
                setState(() {});
              });
            },
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: onOK,
          child: const Text('确定'),
        ),
      ],
    );
  }
}
