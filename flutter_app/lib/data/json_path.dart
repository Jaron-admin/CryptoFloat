import 'dart:convert';

/// Resolves root ($), dot keys, numeric indexes, and quoted bracket keys.
/// Wildcards, filters and expressions are deliberately unsupported.
Object? resolveJsonPath(Object? document, String path) {
  final input = path.trim();
  if (input.isEmpty || input == r'$' || input == r'$.') return document;
  var position = input.startsWith(r'$') ? 1 : 0;
  var value = document;
  var needSeparator = false;
  while (position < input.length) {
    Object key;
    if (input[position] == '.') {
      position++;
      needSeparator = false;
      if (position == input.length || input[position] == '.') {
        throw const FormatException('JSON 路径含有空字段名。');
      }
    } else if (needSeparator && input[position] != '[') {
      throw const FormatException('JSON 字段之间需要点或方括号。');
    }
    if (input[position] == '[') {
      position++;
      if (position >= input.length) {
        throw const FormatException('JSON 路径缺少右方括号。');
      }
      if (input[position] == '"' || input[position] == "'") {
        final quote = input[position++];
        final start = position;
        var escaped = false;
        while (position < input.length) {
          if (!escaped && input[position] == quote) break;
          escaped = !escaped && input[position] == r'\';
          position++;
        }
        if (position >= input.length) {
          throw const FormatException('JSON 路径缺少引号。');
        }
        final rawKey = input.substring(start, position++);
        try {
          key = quote == '"'
              ? jsonDecode('"$rawKey"') as String
              : rawKey.replaceAll(r"\'", "'").replaceAll(r'\\', r'\');
        } on FormatException {
          throw const FormatException('JSON 路径中的引号或转义无效。');
        }
      } else {
        final start = position;
        while (position < input.length &&
            RegExp(r'[0-9]').hasMatch(input[position])) {
          position++;
        }
        final index = int.tryParse(input.substring(start, position));
        if (index == null) throw const FormatException('数组索引需要非负整数。');
        key = index;
      }
      if (position >= input.length || input[position++] != ']') {
        throw const FormatException('JSON 路径缺少右方括号。');
      }
    } else {
      final start = position;
      while (position < input.length && !'.[]'.contains(input[position])) {
        position++;
      }
      if (position == start) throw const FormatException('JSON 路径无效。');
      key = input.substring(start, position);
    }
    if (key is int) {
      if (value is! List || key >= value.length) {
        throw const FormatException('JSON 数组索引不存在。');
      }
      value = value[key];
    } else {
      if (value is! Map || !value.containsKey(key)) {
        throw const FormatException('JSON 字段路径不存在。');
      }
      value = value[key];
    }
    needSeparator = true;
  }
  return value;
}

/// Returns a bounded picker preview with paths usable by [resolveJsonPath].
Map<String, Object?> flattenJson(Object? document, {int maxFields = 500}) {
  final fields = <String, Object?>{};
  void visit(Object? value, String path, int depth) {
    if (fields.length >= maxFields || depth > 32) return;
    if (value is Map) {
      for (final entry in value.entries) {
        if (fields.length >= maxFields) break;
        final key = entry.key.toString();
        final suffix = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(key)
            ? '.$key'
            : '[${jsonEncode(key)}]';
        visit(entry.value, '$path$suffix', depth + 1);
      }
    } else if (value is List) {
      for (
        var i = 0;
        i < value.length && i < 40 && fields.length < maxFields;
        i++
      ) {
        visit(value[i], '$path[$i]', depth + 1);
      }
    } else if (value == null ||
        value is num ||
        value is bool ||
        value is String) {
      fields[path] = value;
    }
  }

  visit(document, r'$', 0);
  return fields;
}
