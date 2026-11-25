import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';

Future<Uint8List?> pickCoverImage() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Imagens PNG ou JPEG',
        extensions: ['png', 'jpg', 'jpeg'],
        mimeTypes: ['image/png', 'image/jpeg'],
        uniformTypeIdentifiers: ['public.png', 'public.jpeg'],
      ),
    ],
  );
  if (file == null) return null;
  if (await file.length() > 25 * 1024 * 1024) {
    throw const FormatException(
      'Imagem grande demais. Escolha um arquivo de até 25 MB.',
    );
  }
  return _coverPng(await file.readAsBytes());
}

Future<Uint8List> _coverPng(Uint8List input) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(input);
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (width, height) {
      final largest = max(width, height);
      if (largest <= 1400) return const ui.TargetImageSize();
      return ui.TargetImageSize(
        width: max(1, (width * 1400 / largest).round()),
        height: max(1, (height * 1400 / largest).round()),
      );
    },
  );
  try {
    final frame = await codec.getNextFrame();
    try {
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw const FormatException('Não foi possível converter a capa.');
      }
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}
