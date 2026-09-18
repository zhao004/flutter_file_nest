import 'package:filenest/app/preview/subtitle_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('解析 SRT 多条对白', () {
    const input =
        '1\n'
        '00:00:01,000 --> 00:00:03,500\n'
        'Hello\n'
        '\n'
        '2\n'
        '00:00:04,000 --> 00:00:06,000\n'
        'World\n';
    final cues = parseSubtitle(input, extension: 'srt');
    expect(cues.length, 2);
    expect(cues.first.start, const Duration(seconds: 1));
    expect(cues.first.end, const Duration(milliseconds: 3500));
    expect(cues.first.text, 'Hello');
    expect(cues[1].text, 'World');
  });

  test('VTT 忽略头部并按 --> 解析', () {
    const input =
        'WEBVTT\n\n'
        '00:01.000 --> 00:02.000\n'
        'Hi\n';
    final cues = parseSubtitle(input, extension: 'vtt');
    expect(cues.single.text, 'Hi');
    expect(cues.single.start, const Duration(seconds: 1));
  });

  test('解析 ASS Dialogue 并清除样式标记', () {
    const input =
        '[Events]\n'
        'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n'
        r'Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,{\i1}Hello\NWorld';
    final cues = parseSubtitle(input, extension: 'ass');
    expect(cues.single.start, const Duration(seconds: 1));
    expect(cues.single.text, 'Hello\nWorld');
  });

  test('时间解析支持逗号、点号与厘秒', () {
    expect(
      parseSubtitleTime('00:00:01,500'),
      const Duration(milliseconds: 1500),
    );
    expect(
      parseSubtitleTime('1:02:03.25'),
      const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 250),
    );
    expect(parseSubtitleTime('bad'), null);
  });
}
