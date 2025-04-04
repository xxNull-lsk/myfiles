import 'package:flutter/material.dart';

enum MessageDialogType {
  info,
  warning,
  error,
}

enum MessageDialogResult {
  ok,
  ok2,
  cancel,
}

class MessageDialog extends StatelessWidget {
  final String title;
  final String content;
  final MessageDialogType type;
  final String okText;
  final String ok2Text;
  final String cancelText;
  const MessageDialog({
    super.key,
    required this.title,
    required this.content,
    required this.type,
    required this.okText,
    required this.ok2Text,
    required this.cancelText,
  });
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          child: Text(cancelText),
          onPressed: () {
            Navigator.of(context).pop(MessageDialogResult.cancel);
          },
        ),
        TextButton(
          child: Text(okText),
          onPressed: () {
            Navigator.of(context).pop(MessageDialogResult.ok);
          },
        ),
        Visibility(
          visible: ok2Text.isNotEmpty,
          child: TextButton(
            child: Text(ok2Text),
            onPressed: () {
              Navigator.of(context).pop(MessageDialogResult.ok2);
            },
          ),
        ),
      ],
    );
  }
}

Future<MessageDialogResult?> showMessageDialog(
    BuildContext context, String title, String content,
    {MessageDialogType type = MessageDialogType.info,
    String okText = "确定",
    String ok2Text = "",
    String cancelText = "取消"}) async {
  return showDialog<MessageDialogResult>(
    context: context,
    builder: (context) {
      return MessageDialog(
        title: title,
        content: content,
        type: type,
        okText: okText,
        ok2Text: ok2Text,
        cancelText: cancelText,
      );
    },
  );
}
