import 'dart:html' as html;

import 'package:flutter/foundation.dart';

bool isMobile() {
  return kIsWeb &&
      (html.window.navigator.userAgent.contains('Mobile') ||
          html.window.navigator.userAgent.contains('Android') ||
          html.window.navigator.userAgent.contains('iPhone'));
}

void disableWebBrowerRightClick() {
  html.document.onContextMenu.listen((event) => event.preventDefault());
}

void openUrl(String url, bool newWindow) {
  html.window.open(url, newWindow ? "_bank" : '_self');
}
