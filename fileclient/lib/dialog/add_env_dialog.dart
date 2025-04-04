import 'package:flutter/material.dart';

class EvnItem {
  String key = "";
  String value = "";
  EvnItem({this.key = "", this.value = ""});
}

class AddEnvDialog extends StatefulWidget {
  const AddEnvDialog({super.key, required this.title, this.evnItem});
  final String title;
  final EvnItem? evnItem;
  @override
  AddEnvDialogState createState() => AddEnvDialogState();
}

class AddEnvDialogState extends State<AddEnvDialog> {
  EvnItem evnItem = EvnItem();

  @override
  void initState() {
    super.initState();
    evnItem = widget.evnItem ?? EvnItem();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: TextEditingController(text: evnItem.key),
            decoration: const InputDecoration(labelText: '变量名'),
            onChanged: (value) => evnItem.key = value,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: TextField(
              maxLines: 999,
              controller: TextEditingController(text: evnItem.value),
              decoration: const InputDecoration(
                  labelText: '变量值', border: OutlineInputBorder()),
              onChanged: (value) => evnItem.value = value,
            ),
          )
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(null);
          },
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(evnItem);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}

Future<EvnItem?> addEvnDialog(BuildContext context,
    {EvnItem? evnItem, String title = "新增环境变量"}) async {
  return showDialog<EvnItem>(
    context: context,
    builder: (context) {
      return AddEnvDialog(
        title: title,
        evnItem: evnItem,
      );
    },
  );
}
