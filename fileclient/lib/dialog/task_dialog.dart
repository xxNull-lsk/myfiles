import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;

import '../backend/task_manager.dart';
import '../event.dart';
import '../global.dart';

enum TaskDialogResult {
  ok,
  cancel,
}

class TaskDialog extends StatefulWidget {
  final String title;
  const TaskDialog({
    super.key,
    required this.title,
  });

  @override
  TaskDialogState createState() => TaskDialogState();
}

class TaskDialogState extends State<TaskDialog> {
  late StreamSubscription<EventTaskUpdate> listenEventTaskUpdate;
  late StreamSubscription<EventTasksChanged> listenEventTasksChanged;
  @override
  void initState() {
    super.initState();
    Global.isShowingTask = true;
    listenEventTaskUpdate =
        EventBusSingleton.instance.on<EventTaskUpdate>().listen((evnt) {
      setState(() {});
    });
    listenEventTasksChanged =
        EventBusSingleton.instance.on<EventTasksChanged>().listen((evnt) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    super.dispose();
    Global.isShowingTask = false;
    listenEventTaskUpdate.cancel();
    listenEventTasksChanged.cancel();
  }

  void onDeleteTask(TransTaskItem task) {
    Global.taskManager!.removeTask(task);
    setState(() {});
  }

  Future<void> onOpen(TransTaskItem task) async {
    String localFilePath = p.dirname(task.localFilePath);
    var result = await OpenFile.open(localFilePath);
    Global.logger?.i("open $localFilePath result: $result");
  }

  Widget? itemBuilder(BuildContext context, int index) {
    if (index >= Global.taskManager!.tasks.length) {
      return null;
    }

    TransTaskItem task = Global.taskManager!.tasks[index];
    if (task.transInfo != null) {
      return ListTile(
        onTap: () => onOpen(task),
        minTileHeight: 32,
        contentPadding: EdgeInsets.fromLTRB(4, 2, 2, 4),
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: task.transInfo!
              .getRow(MediaQuery.of(context).size.width * 0.8 - 128),
        ),
        subtitle: Text(
            "${p.basename(task.localFilePath)} ${task.taskType.name} ${task.status.name}"),
        trailing: IconButton(
            onPressed: () {
              onDeleteTask(task);
            },
            icon: Icon(Icons.delete)),
      );
    }
    if (task.packageInfo != null) {
      return ListTile(
        onTap: () => onOpen(task),
        minTileHeight: 32,
        contentPadding: EdgeInsets.fromLTRB(4, 2, 2, 4),
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: task.packageInfo!
              .getRow(MediaQuery.of(context).size.width * 0.8 - 128),
        ),
        subtitle: Text(
            "${p.basename(task.localFilePath)} ${task.taskType.name} ${task.status.name}"),
        trailing: IconButton(
            onPressed: () {
              onDeleteTask(task);
            },
            icon: Icon(Icons.delete)),
      );
    }
    return ListTile(
      minTileHeight: 32,
      contentPadding: EdgeInsets.fromLTRB(4, 2, 2, 4),
      title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(p.basename(task.localFilePath))),
      subtitle: Text("${task.taskType.name} ${task.status.name}"),
      trailing: IconButton(
          onPressed: () {
            onDeleteTask(task);
          },
          icon: Icon(Icons.delete)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      titlePadding: EdgeInsets.all(8),
      contentPadding: EdgeInsets.all(16),
      content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          height: min(MediaQuery.of(context).size.height * 0.4, 480),
          child: ListView.builder(itemBuilder: itemBuilder)),
    );
  }
}

Future<void> showTaskDialog(BuildContext context,
    {String title = "任务管理"}) async {
  if (Global.isShowingTask) {
    return;
  }
  showDialog<TaskDialogResult>(
    context: context,
    builder: (context) {
      return TaskDialog(
        title: title,
      );
    },
  );
}
