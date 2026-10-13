import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';

import '../data/config_store.dart';

class HeaderImageStore {
  HeaderImageStore({required this.store});
  final ConfigStore store;
  Future<String> importFile(XFile file) async {
    const maxBytes = 1024 * 1024;
    if (await file.length() > maxBytes) {
      throw const FormatException('图标图片不能超过 1 MB。');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('请选择不超过 1 MB 的图片。');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width > 8192 || descriptor.height > 8192) {
        throw const FormatException('图标图片尺寸过大，请选择较小的图片。');
      }
      final scale =
          256 /
          (descriptor.width > descriptor.height
              ? descriptor.width
              : descriptor.height);
      codec = await descriptor.instantiateCodec(
        targetWidth: scale < 1
            ? (descriptor.width * scale).round().clamp(1, 256)
            : descriptor.width,
        targetHeight: scale < 1
            ? (descriptor.height * scale).round().clamp(1, 256)
            : descriptor.height,
      );
      image = (await codec.getNextFrame()).image;
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw const FormatException('图片无法读取。');
      final directory = Directory(
        '${File(store.configPath).parent.path}${Platform.pathSeparator}icons',
      );
      await directory.create(recursive: true);
      final filename = 'icon_${DateTime.now().microsecondsSinceEpoch}.png';
      final destination = File(
        '${directory.path}${Platform.pathSeparator}$filename',
      );
      await destination.writeAsBytes(
        png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
        flush: true,
      );
      return 'icons/$filename';
    } on FormatException {
      rethrow;
    } on FileSystemException {
      throw const FormatException('portable_directory_unwritable');
    } on Object {
      throw const FormatException('图片无法读取，请选择 PNG、JPEG、GIF、WebP、BMP 或 ICO 图片。');
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}
