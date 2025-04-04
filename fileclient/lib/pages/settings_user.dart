import 'dart:convert';

import 'package:fileclient/backend/backend.dart';
import 'package:fileclient/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import '../dialog/add_env_dialog.dart';
import '../global.dart';
import '../pages/util/desktop_check.dart'
    if (dart.library.html) '../pages/util/web_check.dart';

class SettingsUserPage extends StatefulWidget {
  const SettingsUserPage({super.key});

  @override
  State<SettingsUserPage> createState() => _SettingsUserPageState();
}

class _SettingsUserPageState extends State<SettingsUserPage> {
  String password1 = "";
  String password2 = "";
  String email = "";
  bool showDotFiles = false;
  OpenFileMode openFileMode = OpenFileMode.auto;
  Map<String, String> environments = {};
  OpenXtermAsTerminal openXtermAsTerminal = OpenXtermAsTerminal.ask;
  AutoUploadFile autoUploadFile = AutoUploadFile.ask;
  bool changed = false;

  @override
  void initState() {
    super.initState();
    email = Global.userInfo.email;
    openXtermAsTerminal = Global.userInfo.openXtermAsTerminal;
    autoUploadFile = Global.userInfo.autoUploadFile;
    if (Global.userInfo.settings.containsKey("open_file_mode")) {
      for (var element in OpenFileMode.values) {
        if (element.name == Global.userInfo.settings["open_file_mode"]) {
          openFileMode = element;
          break;
        }
      }
    }
    if (Global.userInfo.settings.containsKey("environments")) {
      String envs = Global.userInfo.settings["environments"]!;
      jsonDecode(envs).forEach((key, value) {
        environments[key] = value;
      });
    }
  }

  Future<void> onSave() async {
    UserInfo userInfo = UserInfo();
    userInfo.fromJson(Global.userInfo.toJson());
    // 为空则不修改
    if (password1.isNotEmpty) {
      if (password1 != password2) {
        toastification.show(
          title: const Text('两次输入的密码不一致'),
          autoCloseDuration: const Duration(seconds: 3),
        );
        return;
      }
      userInfo.password = generateSha512(password1);
    } else {
      userInfo.password = "";
    }

    userInfo.email = email;
    userInfo.showDotFiles = showDotFiles;
    await Backend.updateUser(userInfo, (Map result) {
      if (result["code"] != 0) {
        toastification.show(
          title: const Text("保存用户信息失败!"),
          description: Text("错误信息：${result["code"]}(${result["message"]})"),
          autoCloseDuration: const Duration(seconds: 3),
        );
        return;
      }
      Global.userInfo = userInfo;
      toastification.show(
        title: const Text("保存成功"),
        autoCloseDuration: const Duration(seconds: 3),
      );
    }, onFailed);
    await Global.userInfo.changeUserSetting(
        "open_file_mode", openFileMode.name, (a) {}, (a, b, c) {});
    Global.userInfo.changeUserSetting("open_xterm_as_terminal",
        openXtermAsTerminal.name, (a) {}, (a, b, c) {});
    Global.userInfo.changeUserSetting(
        "auto_upload_file", autoUploadFile.name, (a) {}, (a, b, c) {});

    saveEvnironments();
    changed = false;
    setState(() {});
  }

  void saveEvnironments() {
    String envs = jsonEncode(environments);
    Global.userInfo
        .changeUserSetting("environments", envs, (a) {}, (a, b, c) {});
  }

  @override
  Widget build(BuildContext context) {
    String version = Global.clientVersion != null
        ? "${Global.clientVersion!.appName} ${Global.clientVersion!.version}"
        : "";
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Global.serverVersion.url.isEmpty
                ? Text(
                    version,
                    style: TextStyle(color: Colors.grey),
                  )
                : MouseRegion(
                    cursor: SystemMouseCursors.click, // 设置鼠标悬停时光标为手型
                    child: GestureDetector(
                        onTap: () => openUrl(Global.serverVersion.url, true),
                        child: Tooltip(
                          message: Global.serverVersion.url,
                          child: Text(version,
                              style: TextStyle(
                                color: Colors.blue,
                              )),
                        )),
                  ),
            const Spacer(),
          ],
        ),
        actions: [
          Tooltip(
            message: Global.userInfo.id == 0 ? "内置用户无法保存" : "",
            child: TextButton(
              onPressed: Global.userInfo.id == 0 || !changed ? null : onSave,
              child: const Text("保存"),
            ),
          ),
          Container(width: 16)
        ],
      ),
      body: ListView(
        children: [
          const ListTile(
            title: Text(
              "基本信息",
              style: TextStyle(fontSize: 32),
            ),
          ),
          SwitchListTile(
              value: showDotFiles,
              title: const Text("显示隐藏文件"),
              onChanged: (value) {
                setState(() {
                  changed = true;
                  showDotFiles = value;
                });
              }),
          ListTile(
            title: const Text("打开文件模式"),
            trailing: DropdownButton(
              value: openFileMode,
              items: const [
                DropdownMenuItem(
                  value: OpenFileMode.auto,
                  child: Text("自动"),
                ),
                DropdownMenuItem(
                  value: OpenFileMode.singleClickToOpen,
                  child: Text("单击打开"),
                ),
                DropdownMenuItem(
                  value: OpenFileMode.doubleClickToOpen,
                  child: Text("双击打开"),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  changed = true;
                  openFileMode = value!;
                });
              },
            ),
          ),
          ListTile(
            title: const Text("打开xterm文件模式"),
            trailing: DropdownButton(
              value: openXtermAsTerminal,
              items: const [
                DropdownMenuItem(
                  value: OpenXtermAsTerminal.ask,
                  child: Text("询问"),
                ),
                DropdownMenuItem(
                  value: OpenXtermAsTerminal.always,
                  child: Text("始终以终端打开"),
                ),
                DropdownMenuItem(
                  value: OpenXtermAsTerminal.nerver,
                  child: Text("从不以终端打开"),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  changed = true;
                  openXtermAsTerminal = value!;
                });
              },
            ),
          ),
          Visibility(
            visible: !kIsWeb,
            child: ListTile(
              title: const Text("自动上传文件"),
              subtitle: const Text("当双击打开文件时如果文件被改变则自动上传"),
              trailing: DropdownButton(
                value: autoUploadFile,
                items: const [
                  DropdownMenuItem(
                    value: AutoUploadFile.ask,
                    child: Text("询问"),
                  ),
                  DropdownMenuItem(
                    value: AutoUploadFile.always,
                    child: Text("始终自动上传"),
                  ),
                  DropdownMenuItem(
                    value: AutoUploadFile.nerver,
                    child: Text("从不自动上传"),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    changed = true;
                    autoUploadFile = value!;
                  });
                },
              ),
            ),
          ),
          ListTile(
            title: TextField(
              decoration: const InputDecoration(
                labelText: '邮箱',
              ),
              controller: TextEditingController(text: email),
              onChanged: (value) {
                changed = true;
                email = value;
              },
            ),
          ),
          const ListTile(
            title: Text(
              "修改密码",
              style: TextStyle(fontSize: 32),
            ),
          ),
          ListTile(
            title: TextField(
              decoration: const InputDecoration(
                labelText: '用户密码',
                helperText: "留空则不修改",
              ),
              controller: TextEditingController(text: password1),
              obscureText: true,
              onChanged: (value) {
                changed = true;
                password1 = value;
              },
            ),
          ),
          ListTile(
            title: TextField(
              decoration: const InputDecoration(
                labelText: '确认密码',
              ),
              controller: TextEditingController(text: password2),
              obscureText: true,
              onChanged: (value) {
                changed = true;
                password2 = value;
              },
            ),
          ),
          kIsWeb
              ? Container()
              : ListTile(
                  title: Text("缓存大小：${formatBytes(Global.cacheSize, 2)}"),
                  subtitle: Text(Global.cachePath),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      Global.clearCache().then((_) {
                        setState(() {});
                      });
                    },
                  ),
                ),
          ListTile(
            title: Text(
              "环境变量",
              style: TextStyle(fontSize: 32),
            ),
            trailing: IconButton(onPressed: onAddEnv, icon: Icon(Icons.add)),
          ),
          SizedBox(
            height: 320,
            child: ListView.builder(itemBuilder: envBuilder),
          ),
        ],
      ),
    );
  }

  Future<void> onAddEnv() async {
    EvnItem? result = await addEvnDialog(context);
    if (result == null) {
      return;
    }
    setState(() {
      environments[result.key] = result.value;
      saveEvnironments();
    });
  }

  Future<void> onEditEnv(EvnItem item) async {
    String oldKey = item.key;
    EvnItem? result =
        await addEvnDialog(context, evnItem: item, title: "编辑环境变量");
    if (result == null) {
      return;
    }
    setState(() {
      environments.remove(oldKey);
      environments[result.key] = result.value;
      saveEvnironments();
    });
  }

  Widget? envBuilder(BuildContext context, int index) {
    if (index > environments.length) {
      return null;
    }
    if (index == environments.length) {
      return Center(
          child: Text(
        "没有更多环境变量了",
        style: TextStyle(fontSize: 11, color: Colors.grey),
      ));
    }

    String key = environments.keys.elementAt(index);
    String value = environments[key]!;
    return ListTile(
      title: Text(key),
      subtitle: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete),
        onPressed: () {
          setState(() {
            environments.remove(key);
            saveEvnironments();
          });
        },
      ),
      onTap: () => onEditEnv(EvnItem(key: key, value: value)),
    );
  }
}
