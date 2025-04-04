import 'package:flutter/material.dart';

class ProgressDialog extends StatelessWidget {
  //子布局
  final Widget child;

  //加载中是否显示
  final bool loading;

  //进度提醒内容
  final String msg;

  //加载中动画
  final Widget progress;

  //背景透明度
  final double alpha;

  //字体颜色
  final Color textColor;

  const ProgressDialog(
      {Key? key,
      required this.loading,
      this.msg = "",
      this.progress = const CircularProgressIndicator(),
      this.alpha = 0.6,
      this.textColor = Colors.black,
      required this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Widget> widgetList = [];
    widgetList.add(child);
    if (loading) {
      Widget layoutProgress;
      if (msg == "") {
        layoutProgress = Center(
          child: progress,
        );
      } else {
        layoutProgress = Center(
          child: Container(
            padding: const EdgeInsets.all(15.0),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(4.0)),
            child: Container(
              padding: const EdgeInsets.only(left: 20.0),
              alignment: Alignment.centerLeft,
              width: MediaQuery.of(context).size.width * 0.75,
              height: 50.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  progress,
                  Container(
                    margin: const EdgeInsets.only(left: 20.0),
                    child: Text(
                      msg,
                      style: TextStyle(color: textColor, fontSize: 16.0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      widgetList.add(Opacity(
        opacity: alpha,
        child: const ModalBarrier(
          color: Colors.black87,
          dismissible: false,
        ),
      ));
      widgetList.add(layoutProgress);
    }
    return Stack(
      children: widgetList,
    );
  }
}
