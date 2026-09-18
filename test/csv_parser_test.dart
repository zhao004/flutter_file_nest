import 'package:filenest/app/preview/csv_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('解析普通行列', () {
    expect(parseCsv('a,b,c\n1,2,3'), [
      ['a', 'b', 'c'],
      ['1', '2', '3'],
    ]);
  });

  test('忽略结尾换行且保留空字段', () {
    expect(parseCsv('a,b,\n1,,\n'), [
      ['a', 'b', ''],
      ['1', '', ''],
    ]);
  });

  test('引号包裹的逗号与换行不被拆分', () {
    expect(parseCsv('"a,1","b\n2",c'), [
      ['a,1', 'b\n2', 'c'],
    ]);
  });

  test('双引号转义为单个引号', () {
    expect(parseCsv('"say ""hi""",x'), [
      ['say "hi"', 'x'],
    ]);
  });

  test('空输入返回空列表', () {
    expect(parseCsv(''), isEmpty);
  });
}
