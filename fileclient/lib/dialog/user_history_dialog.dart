import 'package:fileclient/event.dart';
import 'package:flutter/material.dart';

import '../pages/util/desktop_check.dart'
    if (dart.library.html) '../pages/util/web_check.dart';
import '../util.dart';

class UserHistoryView extends StatefulWidget {
  const UserHistoryView(
      {super.key,
      required this.isDialog,
      required this.title,
      required this.historyEntries});
  final bool isDialog;
  final String title;
  final List<UserHistoryEntry> historyEntries;

  @override
  UserHistoryViewState createState() => UserHistoryViewState();
}

class UserHistoryViewState extends State<UserHistoryView> {
  Widget buildBody() {
    return SingleChildScrollView(
      child: ListBody(
        children: [
          for (var item in widget.historyEntries)
            ListTile(
              title: Text("${item.action} ${item.ip}"),
              subtitle: Text(humanizerDatetime(item.createdAt)),
            ),
        ],
      ),
    );
  }

  Widget buildDialog() {
    return AlertDialog(
      title: Text("用户【${widget.title}】的历史记录"),
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
        title: Text("用户【${widget.title}】的历史记录"),
      ),
      body: buildBody(),
    );
  }
}

void showUserHistoryDialog(
    BuildContext context, String title, List<UserHistoryEntry> historyEntries) {
  if (isMobile()) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserHistoryView(
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
      return UserHistoryView(
        isDialog: false,
        title: title,
        historyEntries: historyEntries,
      );
    },
  );
}
