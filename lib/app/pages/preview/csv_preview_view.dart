import 'package:flutter/material.dart';

import '../../di/injector.dart';

import '../../models/storage_entry.dart';
import '../../preview/csv_parser.dart';
import '../../preview/preview_limits.dart';
import '../../preview/text_content.dart';
import '../../services/saf_storage.dart';
import 'preview_widgets.dart';

/// CSV 表格预览：首行作为表头，支持双向滚动；超大表格截断显示。
class CsvPreviewView extends StatefulWidget {
  const CsvPreviewView({required this.entry, super.key});

  final StorageEntry entry;

  @override
  State<CsvPreviewView> createState() => _CsvPreviewViewState();
}

class _CsvPreviewViewState extends State<CsvPreviewView> {
  late final StorageGateway _storage = getIt<StorageGateway>();
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
        return _table(snapshot.data!);
      },
    ),
  );

  Widget _table(TextContent content) {
    final rows = parseCsv(content.text);
    if (rows.isEmpty) {
      return const Center(child: Text('没有可显示的表格内容'));
    }
    final header = rows.first;
    final body = rows.skip(1).take(maxCsvRows).toList();
    final truncated = rows.length - 1 > maxCsvRows;
    return Column(
      children: [
        if (content.truncated) TruncatedNotice(entry: widget.entry),
        if (truncated)
          const ListTile(
            dense: true,
            leading: Icon(Icons.info_outline, size: 20),
            title: Text('表格较大，仅显示前 $maxCsvRows 行数据'),
          ),
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columns: [
                    for (final cell in header)
                      DataColumn(
                        label: Text(cell, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  rows: [
                    for (final row in body)
                      DataRow(
                        cells: [
                          for (var index = 0; index < header.length; index++)
                            DataCell(
                              Text(
                                index < row.length ? row[index] : '',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
