import 'package:fileclient/dialog/user_history_dialog.dart';
import 'package:fileclient/event.dart';
import 'package:fileclient/global.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import '../backend/backend.dart';
import '../dialog/create_user_dialog.dart';
import '../dialog/message_dialog.dart';
import '../util.dart';

class SettingsUsersPage extends StatefulWidget {
  const SettingsUsersPage({super.key});

  @override
  State<SettingsUsersPage> createState() => _SettingsUsersPageState();
}

class _SettingsUsersPageState extends State<SettingsUsersPage> {
  final List<UserInfo> _users = [];

  Future<void> onEdit(UserInfo userInfo) async {
    var info = await showDialog<UserInfo>(
      context: context,
      builder: (BuildContext context) {
        return CreateUserDialog(
          userInfo: userInfo,
        );
      },
    );
    if (info == null) {
      return;
    }

    if (info.password.isNotEmpty) {
      info.password = generateSha512(info.password);
    }

    Backend.updateUser(info, (result) {
      if (result["code"] != 0) {
        toastification.show(
          title: Text(result["message"]),
          autoCloseDuration: const Duration(seconds: 3),
        );
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        Backend.getUsers(onGetUserSucceed, onFailed);
      });
    }, onFailed);
  }

  Future<void> onDelete(UserInfo userInfo) async {
    MessageDialogResult? result =
        await showMessageDialog(context, "提醒", "确定要删除用户(${userInfo.name})吗？");
    if (result == null || result != MessageDialogResult.ok) {
      return;
    }
    Backend.deleteUser(userInfo, (result) {
      if (result["code"] != 0) {
        toastification.show(
          title: Text(result["message"]),
          autoCloseDuration: const Duration(seconds: 3),
        );
        return;
      }
      setState(() {
        Backend.getUsers(onGetUserSucceed, onFailed);
      });
    }, onFailed);
  }

  void onGetUserSucceed(Map result) {
    if (!mounted) {
      return;
    }
    if (result["code"] != 0) {
      toastification.show(
        title: Text(result["message"]),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return;
    }
    _users.clear();
    List users = result["data"];
    for (var user in users) {
      UserInfo userInfo = UserInfo();
      userInfo.fromJson(user);
      _users.add(userInfo);
    }
    setState(() {});
  }

  @override
  void initState() {
    Future.delayed(const Duration(milliseconds: 100), () {
      Backend.getUsers(onGetUserSucceed, onFailed);
    });

    super.initState();
  }

  Widget? buildUser(BuildContext context, int index) {
    if (index == _users.length) {
      return null;
    }
    UserInfo userInfo = _users[index];
    return ListTile(
      leading: Text(userInfo.id.toString()),
      title: Row(
        children: [Text(userInfo.name), Text(userInfo.email)],
      ),
      subtitle: Text(userInfo.createdAt.toString()),
      trailing: SizedBox(
        width: 96,
        child: Row(
          children: [
            Expanded(
              child: IconButton(
                  onPressed: () {
                    onEdit(userInfo);
                  },
                  icon: const Icon(Icons.edit)),
            ),
            Expanded(
              child: IconButton(
                  onPressed: () {
                    onDelete(userInfo);
                  },
                  icon: const Icon(Icons.delete)),
            ),
          ],
        ),
      ),
      onTap: () {
        Backend.getUserHistory(
          userInfo.id,
          (result) {
            if (result["code"] != 0) {
              toastification.show(
                title: Text(userInfo.name),
                autoCloseDuration: const Duration(seconds: 3),
              );
              return;
            }
            List<UserHistoryEntry> histories = [];
            for (var item in result["data"]) {
              histories.add(UserHistoryEntry(item));
            }
            showUserHistoryDialog(context, userInfo.name, histories);
          },
          onFailed,
        );
      },
    );
  }

  Future<void> onCreateUser() async {
    var userInfo = await showDialog<UserInfo>(
      context: context,
      builder: (BuildContext context) {
        return const CreateUserDialog();
      },
    );
    if (userInfo == null) {
      return;
    }

    userInfo.password = generateSha512(userInfo.password);
    Backend.createUser(userInfo, (result) {
      if (result["code"] != 0) {
        toastification.show(
          title: Text(result["message"]),
          autoCloseDuration: const Duration(seconds: 3),
        );
        return;
      }
      setState(() {
        Backend.getUsers(onGetUserSucceed, onFailed);
      });
    }, onFailed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: onCreateUser,
            child: const Text("新建用户"),
          ),
          Container(width: 16)
        ],
      ),
      body: ListView.builder(
        itemBuilder: buildUser,
      ),
    );
  }
}
