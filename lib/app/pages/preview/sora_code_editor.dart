import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../preview/editor_surface.dart';

/// 原生平台视图类型；与 MainActivity 注册的工厂名一致。
const String soraEditorViewType = 'filenest/code_editor';

/// 通道名前缀；实际通道为 `filenest/code_editor/<viewId>`。
const String _channelPrefix = 'filenest/code_editor/';

/// 默认编辑器构建器：使用 sora-editor 的 Android 平台视图。
Widget buildSoraCodeEditor(CodeEditorHostConfig config) =>
    SoraCodeEditor(config: config);

/// sora-editor 平台视图宿主。
///
/// 平台视图创建后建立独立通道并把 [CodeEditorController] 交给调用方；
/// 原生内容变化通过 `onChanged` 回推。亮暗与可编辑性变化在重建时下发。
class SoraCodeEditor extends StatefulWidget {
  const SoraCodeEditor({required this.config, super.key});

  final CodeEditorHostConfig config;

  @override
  State<SoraCodeEditor> createState() => _SoraCodeEditorState();
}

class _SoraCodeEditorState extends State<SoraCodeEditor> {
  MethodChannel? _channel;

  @override
  void didUpdateWidget(SoraCodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final channel = _channel;
    if (channel == null) return;
    if (oldWidget.config.dark != widget.config.dark) {
      channel.invokeMethod<void>('setDark', widget.config.dark);
    }
    if (oldWidget.config.editable != widget.config.editable) {
      channel.invokeMethod<void>('setEditable', widget.config.editable);
    }
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _onMethodCall(MethodCall call) async {
    if (call.method == 'onChanged') widget.config.onChanged();
  }

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('$_channelPrefix$id');
    channel.setMethodCallHandler(_onMethodCall);
    final controller = _PlatformCodeEditorController(channel);
    _channel = channel;
    widget.config.onController(controller);
  }

  @override
  Widget build(BuildContext context) => AndroidView(
    viewType: soraEditorViewType,
    layoutDirection: TextDirection.ltr,
    creationParams: {
      'editable': widget.config.editable,
      'dark': widget.config.dark,
    },
    creationParamsCodec: const StandardMessageCodec(),
    onPlatformViewCreated: _onPlatformViewCreated,
  );
}

/// 平台通道实现；同步等待原生返回。
class _PlatformCodeEditorController implements CodeEditorController {
  _PlatformCodeEditorController(this._channel);

  final MethodChannel _channel;

  @override
  Future<void> setText(String text) =>
      _channel.invokeMethod<void>('setText', text);

  @override
  Future<String> readText() async =>
      await _channel.invokeMethod<String>('getText') ?? '';

  @override
  Future<void> setEditable(bool editable) =>
      _channel.invokeMethod<void>('setEditable', editable);

  @override
  Future<void> setDark(bool dark) =>
      _channel.invokeMethod<void>('setDark', dark);

  @override
  Future<void> undo() => _channel.invokeMethod<void>('undo');

  @override
  Future<void> redo() => _channel.invokeMethod<void>('redo');
}
