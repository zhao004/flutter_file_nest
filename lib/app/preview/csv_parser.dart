/// 解析 CSV 文本为行/列字符串（遵循 RFC 4180 的引号与转义规则）。
///
/// 支持双引号包裹字段、字段内逗号与换行、`""` 转义；忽略 `\r`，不把
/// 结尾换行解析成空行。空输入返回空列表。
List<List<String>> parseCsv(String input) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var index = 0;
  while (index < input.length) {
    final char = input[index];
    if (inQuotes) {
      if (char == '"') {
        // `""` 表示字段内的一个双引号。
        if (index + 1 < input.length && input[index + 1] == '"') {
          field.write('"');
          index += 2;
          continue;
        }
        inQuotes = false;
      } else {
        field.write(char);
      }
      index++;
      continue;
    }
    if (char == '"') {
      inQuotes = true;
    } else if (char == ',') {
      row.add(field.toString());
      field.clear();
    } else if (char == '\n') {
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else if (char != '\r') {
      field.write(char);
    }
    index++;
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}
