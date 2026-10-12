import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cryptofloat/data/config_store.dart';
import 'package:cryptofloat/platform/header_image_store.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late HeaderImageStore images;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'cryptofloat_image_test_',
    );
    images = HeaderImageStore(store: ConfigStore(directory: directory.path));
  });
  tearDown(() async => directory.delete(recursive: true));
  test('imports decoded image into private directory without changing original', () async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xFF65D9AA), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(16, 16);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    image.dispose();
    picture.dispose();
    final original = File('${directory.path}/user_icon.png');
    await original.writeAsBytes(bytes);
    final path = await images.importFile(XFile(original.path));
    expect(
      path,
      startsWith(
        '${directory.path}${Platform.pathSeparator}icons${Platform.pathSeparator}',
      ),
    );
    expect(await File(path).exists(), true);
    expect(await original.readAsBytes(), bytes);
    expect(await File('${directory.path}/settings.json').exists(), false);
  });
  test('invalid content is rejected even if extension is png', () async {
    expect(
      images.importFile(
        XFile.fromData(utf8.encode('not an image'), name: 'fake.png'),
      ),
      throwsFormatException,
    );
  });
  test('image over one MiB is rejected before decoding', () async {
    expect(
      images.importFile(
        XFile.fromData(Uint8List(1024 * 1024 + 1), name: 'large.png'),
      ),
      throwsFormatException,
    );
  });
}
