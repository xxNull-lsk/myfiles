import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

bool isMobile() {
  return Platform.isAndroid || Platform.isIOS;
}

void disableWebBrowerRightClick() {}

void openUrl(String url, bool newWindow) {
  launchUrl(
    Uri.parse(url),
    mode: newWindow ? LaunchMode.externalApplication : LaunchMode.inAppWebView,
  );
}
