import 'package:cryptofloat/domain/models.dart';
import 'package:cryptofloat/domain/template_presets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final original = AppConfig.defaults.copyWith(
    displayRows: [
      const DisplayRow(
        id: 'existing',
        segments: [DisplaySegment.literal('原来的文字')],
      ),
    ],
  );
  test('every template appends without deleting default subscriptions or existing rows', () {
    for (final kind in TemplateKind.values) {
      final config = appendTemplate(original, kind, id: 'new');
      expect(config.selectedAssetIds, original.selectedAssetIds);
      expect(config.showDefaultRows, true);
      expect(config.displayRows.first.id, 'existing');
      expect(config.displayRows.length, 2);
      expect(original.displayRows.length, 1);
    }
  });
  test('weather and github have human labels and verified JSON paths', () {
    final weather = appendTemplate(
      original,
      TemplateKind.weather,
      city: '上海',
      id: 'weather',
    ).customSources.single;
    expect(weather.name, '上海天气');
    expect(Uri.parse(weather.url).queryParameters['latitude'], '31.2304');
    expect(weather.fields.first.path, 'current.temperature_2m');
    expect(weather.fields.first.unit, '°C');
    expect(weather.refreshSeconds, 900);
    final github = appendTemplate(
      original,
      TemplateKind.github,
      owner: 'flutter',
      repository: 'flutter',
      id: 'gh',
    ).customSources.single;
    expect(github.url, 'https://api.github.com/repos/flutter/flutter');
    expect(github.fields.first.path, 'stargazers_count');
    expect(github.headers['Accept'], 'application/vnd.github+json');
  });
  test('repeated addition generates distinct row and source ids', () {
    final first = appendTemplate(original, TemplateKind.weather, id: 'same');
    final second = appendTemplate(first, TemplateKind.weather, id: 'same');
    expect(second.displayRows.map((row) => row.id).toSet().length, 3);
    expect(second.customSources.map((source) => source.id).toSet().length, 2);
  });
  test('unsafe repository input and empty reminder are rejected', () {
    expect(
      () => appendTemplate(original, TemplateKind.github, owner: '../private'),
      throwsFormatException,
    );
    expect(
      () => appendTemplate(original, TemplateKind.reminder, text: '  '),
      throwsFormatException,
    );
  });
}
