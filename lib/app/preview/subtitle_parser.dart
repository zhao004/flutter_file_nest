/// 字幕时间轴条目。
class SubtitleCue {
  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });

  final Duration start;
  final Duration end;
  final String text;
}

/// 按扩展名解析字幕文本；SRT/VTT 与 ASS/SSA 语法分别处理。
///
/// 解析失败的行被忽略而不抛异常，保证损坏字幕也能尽量展示可用部分。
List<SubtitleCue> parseSubtitle(String input, {required String extension}) {
  final normalized = extension.toLowerCase();
  if (normalized == 'ass' || normalized == 'ssa') return _parseAss(input);
  return _parseSrtLike(input);
}

/// 解析 SRT/VTT：以空行分块，块内包含 `-->` 的行既为时间轴。
List<SubtitleCue> _parseSrtLike(String input) {
  final cues = <SubtitleCue>[];
  final text = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  for (final block in text.split(RegExp(r'\n[ \t]*\n'))) {
    final lines = block
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) continue;
    final timeIndex = lines.indexWhere((line) => line.contains('-->'));
    if (timeIndex < 0) continue;
    final parts = lines[timeIndex].split('-->');
    if (parts.length < 2) continue;
    final start = parseSubtitleTime(parts[0]);
    final end = parseSubtitleTime(parts[1].trim().split(RegExp(r'\s+')).first);
    if (start == null || end == null) continue;
    cues.add(
      SubtitleCue(
        start: start,
        end: end,
        text: lines.sublist(timeIndex + 1).join('\n').trim(),
      ),
    );
  }
  return cues;
}

/// 解析 ASS/SSA 的 Dialogue 行；前 9 个逗号字段固定，其后为对白文本。
List<SubtitleCue> _parseAss(String input) {
  final cues = <SubtitleCue>[];
  for (final rawLine in input.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (!line.startsWith('Dialogue:')) continue;
    final parts = line.substring('Dialogue:'.length).split(',');
    if (parts.length < 10) continue;
    final start = parseSubtitleTime(parts[1]);
    final end = parseSubtitleTime(parts[2]);
    if (start == null || end == null) continue;
    final text = parts
        .sublist(9)
        .join(',')
        .replaceAll(RegExp(r'\{[^}]*\}'), '')
        .replaceAll(r'\N', '\n')
        .replaceAll(r'\n', '\n')
        .trim();
    cues.add(SubtitleCue(start: start, end: end, text: text));
  }
  return cues;
}

/// 解析 `HH:MM:SS,mmm`、`H:MM:SS.cc` 或 `MM:SS.mmm`；无法解析返回 null。
///
/// 逗号与点号都作为毫秒/厘秒分隔符；超过 3 位的小数按毫秒截断处理。
Duration? parseSubtitleTime(String value) {
  final cleaned = value.trim().replaceAll(',', '.');
  final parts = cleaned.split(':');
  if (parts.length < 2 || parts.length > 3) return null;
  final int hours;
  final int minutes;
  if (parts.length == 3) {
    final parsedHours = int.tryParse(parts[0]);
    final parsedMinutes = int.tryParse(parts[1]);
    if (parsedHours == null || parsedMinutes == null) return null;
    hours = parsedHours;
    minutes = parsedMinutes;
  } else {
    final parsedMinutes = int.tryParse(parts[0]);
    if (parsedMinutes == null) return null;
    hours = 0;
    minutes = parsedMinutes;
  }
  final seconds = double.tryParse(parts.last);
  if (seconds == null) return null;
  final milliseconds = (hours * 3600 + minutes * 60 + seconds) * 1000;
  return Duration(milliseconds: milliseconds.round());
}
