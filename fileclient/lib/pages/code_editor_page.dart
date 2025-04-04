import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:re_highlight/styles/all.dart';
import 'package:path/path.dart' as p;

class CodeEditorPage extends StatefulWidget {
  final String filePath;
  final String initialContent;

  const CodeEditorPage({
    required this.filePath,
    required this.initialContent,
    super.key,
  });

  @override
  State<CodeEditorPage> createState() => _CodeEditorPageState();
}

class _CodeEditorPageState extends State<CodeEditorPage> {
  late final CodeLineEditingController _controller;
  bool _isChanged = false;
  late String _selectedLanguage;
  // 添加主题状态
  late String _selectedTheme = 'androidstudio';

  @override
  void initState() {
    super.initState();
    String ext = p.extension(widget.filePath).replaceAll('.', '');
    if (ext == 'xterm') {
      ext = 'json';
    }
    _selectedLanguage =
        builtinAllLanguages.containsKey(ext) ? ext : 'plaintext';
    _controller = CodeLineEditingController.fromText(widget.initialContent);
  }

  Future<void> _saveFile() async {
    try {
      Navigator.of(context).pop(_controller.text);
    } finally {
      setState(() => _isChanged = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(p.basename(widget.filePath)),
        actions: [
          // 主题选择菜单
          PopupMenuButton<String>(
            icon: Icon(Icons.color_lens),
            onSelected: (theme) => setState(() => _selectedTheme = theme),
            itemBuilder: (context) => builtThemes.keys
                .map((theme) => PopupMenuItem(
                      value: theme,
                      child: ListTile(
                        title: Text(theme),
                        trailing: _selectedTheme == theme
                            ? Icon(Icons.check, color: Colors.blue)
                            : null,
                      ),
                    ))
                .toList(),
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isChanged ? null : _saveFile,
          ),
        ],
      ),
      body: CodeEditor(
        controller: _controller,
        style: CodeEditorStyle(
          fontSize: 18,
          fontFamily: 'monospace',
          selectionColor: Colors.blue.withOpacity(0.3),
          cursorColor: Colors.blue,
          codeTheme: CodeHighlightTheme(languages: {
            _selectedLanguage: CodeHighlightThemeMode(
                mode: builtinAllLanguages[_selectedLanguage]!)
          }, theme: builtThemes[_selectedTheme]! // 使用选择的主题
              ),
        ),
        indicatorBuilder:
            (context, editingController, chunkController, notifier) {
          return Row(
            children: [
              DefaultCodeLineNumber(
                  controller: editingController,
                  notifier: notifier,
                  textStyle: TextStyle(
                    color: Colors.grey,
                  )),
              DefaultCodeChunkIndicator(
                  width: 20, controller: chunkController, notifier: notifier)
            ],
          );
        },
        onChanged: (value) {
          setState(() => _isChanged = true);
        },
      ),
    );
  }
}
