import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'global.dart';
import 'pages/home.dart';
import 'pages/login.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';

import 'pages/shared_view_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.ensureInitialized();

      WindowOptions windowOptions = WindowOptions(
        title: '我的文件',
        size: Size(800, 600),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }
  }
  //Intl.defaultLocale = 'zh_CN';
  runApp(const ToastificationWrapper(
      config: ToastificationConfig(alignment: AlignmentDirectional.topCenter),
      child: MyFilesApp()));
}

class MyGetMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (Global.token.isEmpty) {
      return const RouteSettings(name: "/login");
    }
    return null;
  }
}

class MyFilesApp extends StatelessWidget {
  const MyFilesApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: '我的文件',
      theme: ThemeData(
        listTileTheme: ListTileThemeData(iconColor: Color.fromARGB(255, 82, 183, 255)),
        useMaterial3: false,
        fontFamily: 'NotoSansSC',
      ),
      initialRoute: '/home',
      getPages: [
        GetPage(name: '/login', page: () => const LoginPage()),
        GetPage(
          name: "/home",
          page: () => HomePage(key: Global.filesKey),
          middlewares: [MyGetMiddleware()],
        ),
        GetPage(
          name: "/shared",
          page: () => const SharedViewPage(),
        ),
      ],
    );
  }
}
