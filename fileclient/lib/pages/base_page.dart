import 'package:flutter/material.dart';

import '../global.dart';

abstract class BasePage extends StatefulWidget {
  const BasePage({super.key});

  @factory
  IconData getIcon();

  @factory
  String getTitle();

  @factory
  int getPageID();

  @factory
  PageType getPageType();

  @factory
  Widget getToolbar(bool isLandScape);

  @factory
  Widget? getSidebar() {
    return null;
  }

  @override
  @protected
  @factory
  State createState();
}
