import 'package:flutter/material.dart';

enum InputDataType {
  normal,
  password,
  number,
}

class InputDialog extends StatefulWidget {
  const InputDialog(
      {super.key,
      this.title = "输入对话框",
      this.value = "",
      this.dataType = InputDataType.normal});
  final String title;
  final String value;
  final InputDataType dataType;

  @override
  InputDialogState createState() => InputDialogState();
}

class InputDialogState extends State<InputDialog> {
  String result = "";
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    result = widget.value;
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void onSubmitted(String value) {
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        focusNode: _focusNode,
        controller: TextEditingController(text: result),
        decoration: const InputDecoration(hintText: '请输入内容'),
        onChanged: (value) => result = value,
        onSubmitted: onSubmitted,
        obscureText: widget.dataType == InputDataType.password,
        keyboardType: widget.dataType == InputDataType.number
            ? TextInputType.number
            : null,
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
            Navigator.of(context).pop(result);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}

Future<String?> showInputDialog(BuildContext context,
    {String title = "输入对话框",
    String value = "",
    InputDataType dataType = InputDataType.normal}) async {
  String? result = await showDialog(
    context: context,
    builder: (BuildContext context) {
      return InputDialog(title: title, value: value, dataType: dataType);
    },
  );
  return result;
}
