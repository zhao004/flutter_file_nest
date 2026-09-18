import 'package:flutter/material.dart';
import 'package:filenest/app/pages/preview/text_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const match = TextStyle(backgroundColor: Colors.yellow);

  test('空查询返回整段纯文本', () {
    final span = highlightMatches('abc', '', matchStyle: match);
    expect(span.text, 'abc');
    expect(span.children, isNull);
  });

  test('高亮全部匹配且大小写不敏感', () {
    final span = highlightMatches('Abc abc ABC', 'abc', matchStyle: match);
    final children = span.children!.cast<TextSpan>();
    expect(children.where((item) => item.style == match).length, 3);
    expect(children.map((item) => item.text).join(), 'Abc abc ABC');
  });

  test('保留未匹配的中间文本', () {
    final span = highlightMatches('foo bar foo', 'foo', matchStyle: match);
    final children = span.children!.cast<TextSpan>();
    expect(children.length, 3);
    expect(children[0].text, 'foo');
    expect(children[1].text, ' bar ');
    expect(children[2].text, 'foo');
  });
}
