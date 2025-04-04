import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';

import '../backend/backend.dart';
import '../dialog/message_dialog.dart';
import '../dialog/share_history_dialog.dart';
import '../event.dart';
import '../global.dart';
import '../util.dart';
import 'base_page.dart';

class SharedPage extends BasePage {
  const SharedPage({super.key});

  @override
  int getPageID() => PageType.shared.index;

  @override
  String getTitle() {
    return "共享管理";
  }

  @override
  IconData getIcon() {
    return Icons.share;
  }

  @override
  PageType getPageType() {
    return PageType.shared;
  }

  @override
  State<SharedPage> createState() => _SharedPageState();

  @override
  Widget getToolbar(bool isLandScape) {
    return Container();
  }
}

class _SharedPageState extends State<SharedPage> {
  final List<SharedEntry> _sharedEntries = [];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      Backend.getSharedList(onGetSharedListSucceed, onFailed);
    });
  }

  void onGetSharedListSucceed(Map result) {
    if (result["code"] != 0) {
      toastification.show(
          title: const Text("获取共享列表失败"),
          description: Text("${result["code"]}(${result["message"]})"),
          autoCloseDuration: const Duration(seconds: 5));
      return;
    }
    _sharedEntries.clear();
    for (var item in result["data"]) {
      SharedEntry entry = SharedEntry();
      entry.fromJson(item);
      _sharedEntries.add(entry);
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> onViewHistory(SharedEntry sharedEntry) async {
    Backend.getSharedHistory(sharedEntry.sid, (result) {
      if (result["code"] != 0) {
        toastification.show(
            title: const Text("获取历史记录失败"),
            description: Text("${result["code"]}(${result["message"]})"),
            autoCloseDuration: const Duration(seconds: 5));
        return;
      }
      List<SharedHistoryEntry> historyEntries = [];
      for (var item in result["data"]) {
        SharedHistoryEntry entry = SharedHistoryEntry();
        entry.fromJson(item);
        historyEntries.add(entry);
      }
      showSharedHistoryDialog(context, sharedEntry.name, historyEntries);
    }, onFailed);
  }

  Future<void> onDeleteShred(SharedEntry sharedEntry) async {
    MessageDialogResult? result = await showMessageDialog(
        context, "提醒", "确定要删除分享(${sharedEntry.name})吗？");
    if (result == null || result != MessageDialogResult.ok) {
      return;
    }
    Backend.deleteShared(sharedEntry.sid, (result) {
      if (result["code"] != 0) {
        toastification.show(
            title: const Text("删除共享失败"),
            description: Text("${result["code"]}(${result["message"]})"),
            autoCloseDuration: const Duration(seconds: 5));
        return;
      }
      Backend.getSharedList(onGetSharedListSucceed, onFailed);
    }, onFailed);
  }

  Widget itemBuilder(BuildContext context, int index) {
    if (index >= _sharedEntries.length) {
      return const Center(
        child: Text(
          "没有更多数据",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    String info =
        "${_sharedEntries[index].path} | ${_sharedEntries[index].createdAt}";
    if (_sharedEntries[index].maxCount > 0) {
      info +=
          " | 下载限制(${_sharedEntries[index].currentCount}/${_sharedEntries[index].maxCount})";
    } else {
      info += " | 下载次数(${_sharedEntries[index].currentCount})";
    }
    if (_sharedEntries[index].maxUploadSize > 0) {
      info +=
          " | 上传限制(${formatBytes(_sharedEntries[index].currentUploadSize, 2)}/${formatBytes(_sharedEntries[index].maxUploadSize, 2)})";
    } else {
      info +=
          " | 已经上传(${formatBytes(_sharedEntries[index].currentUploadSize, 2)})";
    }
    if (_sharedEntries[index].timeLimited > 0) {
      DateTime expireAt = _sharedEntries[index]
          .createdAt
          .add(Duration(days: _sharedEntries[index].timeLimited));
      info += " | 过期时间(${expireAt.year}-${expireAt.month}-${expireAt.day})";
    } else {
      info += " | 永久有效";
    }
    return ListTile(
      minTileHeight: 32,
      leading: IconButton(
          onPressed: () async {
            String text =
                "${Global.backendURL}/front/shared/?sid=${_sharedEntries[index].sid}&code=${_sharedEntries[index].code}";
            await Clipboard.setData(ClipboardData(text: text));
            toastification.show(
                title: const Text("复制成功"),
                autoCloseDuration: const Duration(seconds: 5));
          },
          icon: const Icon(Icons.copy)),
      title: Text(_sharedEntries[index].name),
      subtitle: Text(info),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
              onPressed: () => onDeleteShred(_sharedEntries[index]),
              icon: const Icon(Icons.delete)),
          IconButton(
              onPressed: () => onViewHistory(_sharedEntries[index]),
              icon: const Icon(Icons.history)),
        ],
      ),
      onTap: () {
        Get.toNamed(
            "/shared?sid=${_sharedEntries[index].sid}&code=${_sharedEntries[index].code}");
        //Get.toNamed("/shared?sid=${_sharedEntries[index].sid}");
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Colors.white,
        child: ListView.builder(
            itemBuilder: itemBuilder, itemCount: _sharedEntries.length + 1));
  }
}
