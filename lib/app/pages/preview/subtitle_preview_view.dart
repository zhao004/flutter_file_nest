import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../file_type/file_extension_map.dart';
import '../../models/storage_entry.dart';
import '../../preview/subtitle_parser.dart';
import '../../preview/text_content.dart';
import '../../services/saf_storage.dart';
import 'preview_widgets.dart';

/// 字幕预览：按时间轴列出 SRT/VTT/ASS 的对白，便于核对时间与文本。
///
/// 视频播放器自动匹配同目录字幕不在本页范围内，后续在播放器中实现。
class SubtitlePreviewView extends StatefulWidget {
  const SubtitlePreviewView({required this.entry, super.key});

  final StorageEntry entry;

  @override
  State<SubtitlePreviewView> createState() => _SubtitlePreviewViewState();
}

class _SubtitlePreviewViewState extends State<SubtitlePreviewView> {
  late final StorageGateway _storage = Get.find<StorageGateway>();
  late Future<TextContent> _future = _load();

  Future<TextContent> _load() => loadTextContent(_storage, widget.entry);

  void _retry() => setState(() => _future = _load());

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
          tooltip: '用其他应用打开',
          onPressed: () => _storage.openFile(widget.entry),
          icon: const Icon(Icons.open_in_new),
        ),
      ],
    ),
    body: FutureBuilder<TextContent>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final error = snapshot.error;
        if (error != null) {
          return PreviewErrorView(
            entry: widget.entry,
            message: previewErrorMessage(error),
            onRetry: _retry,
          );
        }
        final content = snapshot.data!;
        final cues = parseSubtitle(
          content.text,
          extension: fileExtension(widget.entry.name),
        );
        if (cues.isEmpty) {
          return const Center(child: Text('没有可显示的字幕内容'));
        }
        return Column(
          children: [
            if (content.truncated) TruncatedNotice(entry: widget.entry),
            Expanded(
              child: ListView.separated(
                itemCount: cues.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final cue = cues[index];
                  return ListTile(
                    dense: true,
                    leading: Text(
                      '${_format(cue.start)}\n${_format(cue.end)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(cue.text.isEmpty ? '（空对白）' : cue.text),
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// 字幕时间的 MM:SS.mmm 展示。
String _format(Duration value) {
  final total = value.inMilliseconds < 0 ? 0 : value.inMilliseconds;
  String two(int part) => part.toString().padLeft(2, '0');
  final hours = total ~/ 3600000;
  final minutes = (total % 3600000) ~/ 60000;
  final seconds = (total % 60000) ~/ 1000;
  final millis = total % 1000;
  final base =
      '${two(minutes)}:${two(seconds)}.${millis.toString().padLeft(3, '0')}';
  return hours > 0 ? '${two(hours)}:$base' : base;
}
