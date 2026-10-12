import 'dart:convert';
import 'dart:io';

/// Run from flutter_app before `flutter gen-l10n` after editing fragments.
void main() {
  final directory = Directory('tool/l10n_fragments');
  final files = directory.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final locales = <String, Map<String, Object?>>{};
  for (final locale in ['en', 'zh']) {
    final merged = <String, Object?>{'@@locale': locale};
    for (final file in files.where((f) => f.path.endsWith('_$locale.arb'))) {
      final fragment =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in fragment.entries) {
        if (entry.key.startsWith('@@')) continue;
        if (merged.containsKey(entry.key)) {
          throw StateError('Duplicate key: ${entry.key}');
        }
        merged[entry.key] = entry.value;
      }
    }
    locales[locale] = merged;
  }
  final english = locales['en']!.keys.where((k) => !k.startsWith('@')).toSet();
  final chinese = locales['zh']!.keys.where((k) => !k.startsWith('@')).toSet();
  if (english.difference(chinese).isNotEmpty ||
      chinese.difference(english).isNotEmpty) {
    throw StateError('Locale keys do not match');
  }
  Directory('lib/l10n/catalog').createSync(recursive: true);
  for (final entry in locales.entries) {
    File('lib/l10n/catalog/app_${entry.key}.arb').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(entry.value)}\n',
    );
  }
  stdout.writeln('Merged ${english.length} messages per locale.');
}
