import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

typedef VirtualKeyboardCallback = void Function(String key, TerminalKey value);

class VirtualKeyboardView extends StatefulWidget {
  const VirtualKeyboardView(this.keyboard, {required this.callback, super.key});

  final VirtualKeyboard keyboard;
  final VirtualKeyboardCallback callback;
  @override
  State<VirtualKeyboardView> createState() => _VirtualKeyboardViewState();
}

enum KeyboardMode { normal, fn, fx }

class _VirtualKeyboardViewState extends State<VirtualKeyboardView> {
  final Map<String, TerminalKey> keyMap = {
    "ESC": TerminalKey.escape,
    "/": TerminalKey.nonConvert,
    "|": TerminalKey.nonConvert,
    "-": TerminalKey.nonConvert,
    "HOME": TerminalKey.home,
    "↑": TerminalKey.arrowUp,
    "END": TerminalKey.end,
    "PGUP": TerminalKey.pageUp,
    "FN": TerminalKey.none,
    "TAB": TerminalKey.tab,
    "CTL": TerminalKey.control,
    "ALT": TerminalKey.alt,
    ":": TerminalKey.nonConvert,
    "←": TerminalKey.arrowLeft,
    "↓": TerminalKey.arrowDown,
    "→": TerminalKey.arrowRight,
    "PGDN": TerminalKey.pageDown,
    "FX": TerminalKey.none,
  };

  final Map<String, TerminalKey> keyFXMap = {
    "`": TerminalKey.nonConvert,
    "<": TerminalKey.nonConvert,
    ">": TerminalKey.nonConvert,
    "_": TerminalKey.nonConvert,
    "&": TerminalKey.nonConvert,
    "~": TerminalKey.nonConvert,
    "!": TerminalKey.nonConvert,
    "@": TerminalKey.nonConvert,
    "FN": TerminalKey.none,
    "#": TerminalKey.nonConvert,
    "\$": TerminalKey.nonConvert,
    "%": TerminalKey.nonConvert,
    "^": TerminalKey.nonConvert,
    "?": TerminalKey.nonConvert,
    "\\": TerminalKey.nonConvert,
    ".": TerminalKey.nonConvert,
    ",": TerminalKey.nonConvert,
    "FX": TerminalKey.none,
    ";": TerminalKey.nonConvert,
    "\"": TerminalKey.nonConvert,
    "'": TerminalKey.nonConvert,
    "*": TerminalKey.nonConvert,
    "+": TerminalKey.nonConvert,
    "=": TerminalKey.nonConvert,
    "(": TerminalKey.nonConvert,
    ")": TerminalKey.nonConvert,
    "{": TerminalKey.nonConvert,
    "}": TerminalKey.nonConvert,
    "[": TerminalKey.nonConvert,
    "]": TerminalKey.nonConvert,
  };

  final Map<String, TerminalKey> keyFNMap = {
    "F1": TerminalKey.f1,
    "F2": TerminalKey.f2,
    "F3": TerminalKey.f3,
    "F4": TerminalKey.f4,
    "F5": TerminalKey.f5,
    "F6": TerminalKey.f6,
    "F7": TerminalKey.f7,
    "F8": TerminalKey.f8,
    "FN": TerminalKey.none,
    "F9": TerminalKey.f9,
    "F10": TerminalKey.f10,
    "F11": TerminalKey.f11,
    "F12": TerminalKey.f12,
    "DEL": TerminalKey.delete,
    "INS": TerminalKey.insert,
    "": TerminalKey.none,
    " ": TerminalKey.none,
    "FX": TerminalKey.none,
  };
  KeyboardMode keyboardMode = KeyboardMode.normal;
  Widget getCtl(Size size, TextStyle ts) {
    return TextButton(
      style: ButtonStyle(
        padding: WidgetStateProperty.all(
          EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        ),
        minimumSize: WidgetStateProperty.all(size),
        textStyle: WidgetStateProperty.all(ts),
        backgroundColor: widget.keyboard.ctrl
            ? WidgetStateProperty.all(Colors.blue)
            : WidgetStateProperty.all(Colors.transparent),
        foregroundColor: widget.keyboard.ctrl
            ? WidgetStateProperty.all(Colors.white)
            : WidgetStateProperty.all(Colors.blue),
      ),
      onPressed: () {
        widget.keyboard.ctrl = !widget.keyboard.ctrl;
        setState(() {});
      },
      child: Text("CTL"),
    );
  }

  Widget getAlt(Size size, TextStyle ts) {
    return TextButton(
      style: ButtonStyle(
        padding: WidgetStateProperty.all(
          EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        ),
        minimumSize: WidgetStateProperty.all(size),
        textStyle: WidgetStateProperty.all(ts),
        backgroundColor: widget.keyboard.alt
            ? WidgetStateProperty.all(Colors.blue)
            : WidgetStateProperty.all(Colors.transparent),
        foregroundColor: widget.keyboard.alt
            ? WidgetStateProperty.all(Colors.white)
            : WidgetStateProperty.all(Colors.blue),
      ),
      onPressed: () {
        widget.keyboard.alt = !widget.keyboard.alt;
        setState(() {});
      },
      child: Text("ALT"),
    );
  }

  Widget getBtn(String key, Size size, TextStyle ts) {
    if (key == "CTL") {
      return getCtl(size, ts);
    }
    if (key == "ALT") {
      return getAlt(size, ts);
    }
    return TextButton(
      style: ButtonStyle(
        padding: WidgetStateProperty.all(
          EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        ),
        minimumSize: WidgetStateProperty.all(size),
        textStyle: WidgetStateProperty.all(ts),
      ),
      onPressed: () {
        if (key == "FN") {
          keyboardMode = keyboardMode == KeyboardMode.fn
              ? KeyboardMode.normal
              : KeyboardMode.fn;
          setState(() {});
          return;
        }
        if (key == "FX") {
          keyboardMode = keyboardMode == KeyboardMode.fx
              ? KeyboardMode.normal
              : KeyboardMode.fx;
          setState(() {});
          return;
        }
        Map<String, TerminalKey> keys;
        switch (keyboardMode) {
          case KeyboardMode.normal:
            keys = keyMap;
            break;
          case KeyboardMode.fn:
            keys = keyFNMap;
            break;
          case KeyboardMode.fx:
            keys = keyFXMap;
            break;
        }
        if (keys[key]! == TerminalKey.none) {
          return;
        }
        widget.callback(key, keys[key]!);
      },
      child: Text(key),
    );
  }

  ScrollController _ctlLine1 = ScrollController();
  ScrollController _ctlLine2 = ScrollController();

  @override
  Widget build(BuildContext context) {
    List<String> keys;
    switch (keyboardMode) {
      case KeyboardMode.normal:
        keys = keyMap.keys.toList();
        break;
      case KeyboardMode.fn:
        keys = keyFNMap.keys.toList();
        break;
      case KeyboardMode.fx:
        keys = keyFXMap.keys.toList();
        break;
    }
    Size size = Size(38, 28);
    TextStyle ts = TextStyle(fontSize: 12, fontWeight: FontWeight.bold);
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 0,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: _ctlLine1,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 0,
            children: [
              ...keys.sublist(0, 9).map((e) =>
                  SizedBox.fromSize(size: size, child: getBtn(e, size, ts))),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: _ctlLine2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 0,
            children: [
              ...keys.sublist(9).map((e) =>
                  SizedBox.fromSize(size: size, child: getBtn(e, size, ts))),
            ],
          ),
        ),
      ],
    );
  }
}

class VirtualKeyboard extends TerminalInputHandler with ChangeNotifier {
  final TerminalInputHandler _inputHandler;

  VirtualKeyboard(this._inputHandler);

  bool _ctrl = false;

  bool get ctrl => _ctrl;

  set ctrl(bool value) {
    if (_ctrl != value) {
      _ctrl = value;
      notifyListeners();
    }
  }

  bool _alt = false;

  bool get alt => _alt;

  set alt(bool value) {
    if (_alt != value) {
      _alt = value;
      notifyListeners();
    }
  }

  @override
  String? call(TerminalKeyboardEvent event) {
    return _inputHandler.call(event.copyWith(
      ctrl: event.ctrl || _ctrl,
      alt: event.alt || _alt,
      shift: event.shift,
    ));
  }
}
