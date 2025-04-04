import 'package:fileclient/global.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class CreateUserDialog extends StatefulWidget {
  const CreateUserDialog({super.key, this.userInfo, this.title = "新建用户"});
  final String title;
  final UserInfo? userInfo;

  @override
  CreateUserDialogState createState() => CreateUserDialogState();
}

class CreateUserDialogState extends State<CreateUserDialog> {
  void onFailed(Exception ex) {
    toastification.show(
      title: Text(ex.toString()),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  bool isAdmin = false;
  bool enabled = true;
  bool showDotFiles = false;

  String name = "";
  String password1 = "";
  String password2 = "";
  String email = ""; 
  String rootDir = "/";

  @override
  void initState() {
    isAdmin = widget.userInfo?.isAdmin ?? false;
    enabled = widget.userInfo?.enabled ?? true;
    name = widget.userInfo?.name ?? "";
    email = widget.userInfo?.email ?? "";
    rootDir = widget.userInfo?.rootDir ?? "/";

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: '用户名',
            ),
            controller: TextEditingController(text: name),
            onChanged: (value) {
              name = value;
            },
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: '用户密码',
            ),
            controller: TextEditingController(text: password1),
            obscureText: true,
            onChanged: (value) {
              password1 = value;
            },
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: '校验密码',
            ),
            controller: TextEditingController(text: password2),
            obscureText: true,
            onChanged: (value) {
              password2 = value;
            },
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: '邮箱',
            ),
            controller: TextEditingController(text: email),
            onChanged: (value) {
              email = value;
            },
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: '根目录',
            ),
            controller: TextEditingController(text: rootDir),
            onChanged: (value) {
              rootDir = value;
            },
          ),
          SwitchListTile(
            title: const Text('管理员'),
            onChanged: (bool? value) {
              isAdmin = value ?? false;
              setState(() {});
            },
            value: isAdmin,
          ),
          SwitchListTile(
            title: const Text('启用'),
            onChanged: (bool? value) {
              enabled = value ?? false;
              setState(() {});
            },
            value: enabled,
          ),
          SwitchListTile(
            title: const Text('显示隐藏文件'),
            onChanged: (bool? value) {
              showDotFiles = value ?? false;
              setState(() {});
            },
            value: showDotFiles,
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
          onPressed: () {
            if (name.isEmpty) {
              toastification.show(
                title: const Text('用户名不能为空'),
                autoCloseDuration: const Duration(seconds: 3),
              );
              return;
            }
            if (widget.userInfo == null && password1.isEmpty) {
              toastification.show(
                title: const Text('密码不能为空'),
                autoCloseDuration: const Duration(seconds: 3),
              );
              return;
            }
            if (password1 != password2) {
              toastification.show(
                title: const Text('密码不一致'),
                autoCloseDuration: const Duration(seconds: 3),
              );
              return;
            }
            UserInfo userInfo =
                widget.userInfo != null ? widget.userInfo! : UserInfo();
            userInfo.name = name;
            userInfo.password = password1;
            userInfo.email = email;
            userInfo.rootDir = rootDir;
            userInfo.isAdmin = isAdmin;
            userInfo.enabled = enabled;
            userInfo.showDotFiles = showDotFiles;
            Navigator.of(context).pop(userInfo);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
