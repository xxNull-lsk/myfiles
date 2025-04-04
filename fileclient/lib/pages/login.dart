import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ionicons/ionicons.dart';
import 'package:toastification/toastification.dart';
import '../pages/util/desktop_check.dart'
    if (dart.library.html) '../pages/util/web_check.dart';

import '../backend/backend.dart';
import '../global.dart';
import '../util.dart';
import 'loading.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  var _obscureText = true;
  var _iconEye = const Icon(Ionicons.eye_off);
  String _username = Global.username;
  String _password = '';
  String _serverURL = Global.backendURL;
  bool _loading = false;
  bool _showLogin = false;
  bool _rememberPassword = true;
  final FocusNode _serverFocusNode = FocusNode();
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  Future<bool> isInstallMode() async {
    if (Global.serverVersion.commit.isEmpty) {
      await Global.initVersionAsync();
    }
    if (!Global.serverVersion.installMode) {
      return false;
    }
    toastification.show(
      type: ToastificationType.error,
      title: const Text('无法登录'),
      description: const Text('当前安装模式下，请通过网页访问安装地址，完成安装后再登录！3秒后自动跳转...'),
      autoCloseDuration: const Duration(seconds: 3),
    );
    Future.delayed(const Duration(seconds: 3), () {
      openUrl(Global.backendURL, false);
    });
    return true;
  }

  @override
  void initState() {
    Global.init().then((_) {
      isInstallMode();
      _serverURL = Global.backendURL;
      _username = Global.username;
      if (Global.token.isNotEmpty &&
          Global.backendURL.isNotEmpty &&
          Global.username.isNotEmpty &&
          (Global.sessionId.isNotEmpty || Global.password.isNotEmpty)) {
        onLogin();
      } else {
        _showLogin = true;
        Global.token = "";
        Global.sessionId = "";
        if (kDebugMode && _username.isEmpty) {
          _username = "admin";
          _password = "123456";
        }
        setState(() {});
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _serverFocusNode.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> checkLogin() async {
    if (_username.isEmpty) {
      _usernameFocusNode.requestFocus();
      return;
    }

    if (_serverURL.isEmpty) {
      _serverFocusNode.requestFocus();
      return;
    }
    if (_password.isEmpty) {
      _passwordFocusNode.requestFocus();
      return;
    }
    return onLogin();
  }

  Future<void> onLogin() async {
    if (await isInstallMode()) {
      return;
    }
    bool ret = await Global.requestStoragePermission();
    if (!ret) {
      return;
    }

    setState(() {
      _loading = true;
    });

    Backend.doLogin(_rememberPassword, _serverURL, _username,
        _password == "" ? Global.password : generateSha512(_password),
        (result) {
      setState(() {
        _loading = false;
      });
      Get.offAllNamed("/home");
    }, (ex, method, url) {
      setState(() {
        _showLogin = true;
        _loading = false;
      });
      Global.token = "";
      Global.sessionId = "";
      Global.save();
      toastification.show(
        type: ToastificationType.error,
        title: const Text('登录失败！'),
        description: Text(ex.toString()),
        autoCloseDuration: const Duration(seconds: 5),
      );
    });
  }

  Widget buildBody(BuildContext context) {
    return SingleChildScrollView(
      child: Column(children: [
        SizedBox(
          width: 128,
          height: 128,
          child: Image.asset('assets/images/app.png'),
        ),
        Visibility(
            visible: !kIsWeb || kDebugMode,
            child: TextField(
              focusNode: _serverFocusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (String val) => checkLogin(),
              controller: TextEditingController(text: _serverURL),
              onChanged: (String val) => _serverURL = val,
              decoration: const InputDecoration(
                  labelText: "服务器",
                  hintText: "服务器地址",
                  prefixIcon: Icon(Ionicons.server)),
            )),
        TextField(
          focusNode: _usernameFocusNode,
          textInputAction: TextInputAction.done,
          onSubmitted: (String val) => checkLogin(),
          controller: TextEditingController(text: _username),
          onChanged: (String val) => _username = val,
          decoration: const InputDecoration(
              labelText: "⽤户名",
              hintText: "您的⽤户名",
              prefixIcon: Icon(Ionicons.person)),
        ),
        Row(
          children: [
            Expanded(
                child: TextField(
              focusNode: _passwordFocusNode,
              controller: TextEditingController(text: _password),
              onChanged: (String val) => _password = val,
              textInputAction: TextInputAction.done,
              onSubmitted: (String val) => checkLogin(),
              decoration: const InputDecoration(
                  labelText: "密码",
                  hintText: "您的登录密码",
                  prefixIcon: Icon(Ionicons.lock_closed)),
              obscureText: _obscureText,
            )),
            SizedBox(
              width: 48,
              child: IconButton(
                iconSize: 24,
                icon: _iconEye,
                onPressed: () {
                  _obscureText = !_obscureText;
                  if (_obscureText) {
                    _iconEye = const Icon(Ionicons.eye_off);
                  } else {
                    _iconEye = const Icon(Ionicons.eye);
                  }
                  setState(() {});
                },
              ),
            ),
          ],
        ),
        Row(
          children: [
            SizedBox(
              height: 48,
              width: 180,
              child: SwitchListTile(
                  title: const Text("记住密码"),
                  value: _rememberPassword,
                  onChanged: (val) {
                    _rememberPassword = val;
                    setState(() {});
                  }),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Spacer(),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: onLogin,
                  child: const Text(
                    "登录",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    String version = Global.clientVersion != null
        ? "${Global.clientVersion!.appName} ${Global.clientVersion!.version}"
        : "";
    return Scaffold(
        body: ProgressDialog(
      loading: _loading,
      child: Column(
        children: [
          Spacer(),
          Center(
            child: SizedBox(
              width: 640,
              child: _showLogin
                  ? buildBody(context)
                  : const Center(
                      child: Text("正在登录..."),
                    ),
            ),
          ),
          Spacer(),
          Row(
            children: [
              const Spacer(),
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
                        ),
                      ),
                    ),
              const Spacer(),
            ],
          ),
        ],
      ),
    ));
  }
}
