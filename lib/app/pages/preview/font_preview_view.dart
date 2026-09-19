import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../di/injector.dart';
import '../../i18n/app_l10n.dart';
import '../../localization.dart';
import '../../models/storage_entry.dart';
import '../../services/saf_storage.dart';
import 'preview_widgets.dart';

/// 字体预览：动态加载 TTF/OTF 并展示字符集与样文。
///
/// Flutter 无法直接加载字体集合（`.ttc`）与 Web 字体，这些格式在解析层
/// 已交给系统打开。加载失败时提供重试与外部打开。
class FontPreviewView extends StatefulWidget {
  const FontPreviewView({required this.entry, super.key});

  final StorageEntry entry;

  @override
  State<FontPreviewView> createState() => _FontPreviewViewState();
}

class _FontPreviewViewState extends State<FontPreviewView> {
  /// 字体族名需在进程内唯一，避免不同字体互相覆盖。
  late final String _family =
      'preview_font_${widget.entry.uri.hashCode.toUnsigned(32)}';

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await getIt<StorageGateway>().readDocument(widget.entry);
      if (bytes == null || bytes.isEmpty) {
        throw StateError('empty font');
      }
      final loader = FontLoader(_family)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppL10n.current.fontLoadFailed;
      });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.entry.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          tooltip: context.l10n.commonOpenExternal,
          onPressed: () => getIt<StorageGateway>().openFile(widget.entry),
          icon: const Icon(Icons.open_in_new),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? PreviewErrorView(
            entry: widget.entry,
            message: _error!,
            icon: Icons.font_download_outlined,
            onRetry: _retry,
          )
        : _sample(),
  );

  Widget _sample() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.entry.name,
          style: TextStyle(fontFamily: _family, fontSize: 22),
        ),
        const SizedBox(height: 16),
        Text('Aa', style: TextStyle(fontFamily: _family, fontSize: 84)),
        const SizedBox(height: 16),
        Text(
          'ABCDEFGHIJKLMNOPQRSTUVWXYZ\n'
          'abcdefghijklmnopqrstuvwxyz\n'
          '0123456789 !@#\$%&*()',
          style: TextStyle(fontFamily: _family, fontSize: 20, height: 1.6),
        ),
        const SizedBox(height: 16),
        Text(
          'The quick brown fox jumps over the lazy dog.',
          style: TextStyle(fontFamily: _family, fontSize: 18, height: 1.6),
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.fontSample,
          style: TextStyle(fontFamily: _family, fontSize: 18, height: 1.8),
        ),
      ],
    ),
  );
}
