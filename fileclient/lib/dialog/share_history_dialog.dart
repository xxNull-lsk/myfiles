import 'package:fileclient/event.dart';
import '../pages/util/desktop_check.dart'
    if (dart.library.html) '../pages/util/web_check.dart';
import 'package:flutter/material.dart';

import '../util.dart';

class SharedHistoryDialog extends StatefulWidget {
  const SharedHistoryDialog(
      {super.key,
      required this.isDialog,
      required this.title,
      required this.historyEntries});
  final bool isDialog;
  final String title;
  final List<SharedHistoryEntry> historyEntries;

  @override
  SharedHistoryDialogState createState() => SharedHistoryDialogState();
}

class SharedHistoryDialogState extends State<SharedHistoryDialog> {
  Widget buildBody() {
    return SingleChildScrollView(
        child: ListBody(children: [
      for (var item in widget.historyEntries)
        ListTile(
          title: Text(
              "${item.action} ${item.information['path_in_shared'] ?? ""} ${item.ip}"),
          subtitle: Text(humanizerDatetime(item.createdAt)),
        )
    ]));
  }

  Widget buildDialog() {
    return AlertDialog(
      title: Text("共享【${widget.title}】的历史记录"),
      content: buildBody(),
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

  @override
  Widget build(BuildContext context) {
    if (widget.isDialog) {
      return buildDialog();
    }
    return Scaffold(
      appBar: AppBar(
        leading: Tooltip(
          message: "返回",
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        title: Text("共享【${widget.title}】的历史记录"),
      ),
      body: buildBody(),
    );
  }
}

void showSharedHistoryDialog(BuildContext context, String title,
    List<SharedHistoryEntry> historyEntries) {
  if (isMobile()) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SharedHistoryDialog(
          isDialog: false,
          title: title,
          historyEntries: historyEntries,
        ),
      ),
    );
    return;
  }
  showDialog(
    context: context,
    builder: (context) {
      return SharedHistoryDialog(
        isDialog: true,
        title: title,
        historyEntries: historyEntries,
      );
    },
  );
}
