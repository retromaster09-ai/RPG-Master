import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_master_set/notebook_format.dart';
import 'package:rpg_master_set/picture_background.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'remove o branco da borda e preserva o branco dentro do desenho',
    () async {
      final pixels = Uint8List(5 * 5 * 4)..fillRange(0, 5 * 5 * 4, 255);
      for (var y = 1; y <= 3; y++) {
        for (var x = 1; x <= 3; x++) {
          if (x == 2 && y == 2) continue;
          final offset = (y * 5 + x) * 4;
          pixels[offset + 1] = 0;
          pixels[offset + 2] = 0;
        }
      }
      final decoded = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels,
        5,
        5,
        ui.PixelFormat.rgba8888,
        decoded.complete,
      );
      final original = await decoded.future;
      final png = (await original.toByteData(format: ui.ImageByteFormat.png))!;
      original.dispose();
      final transparent = await removePictureBackground(
        png.buffer.asUint8List(),
        PictureBackground.white,
        26,
      );
      final codec = await ui.instantiateImageCodec(transparent);
      final result = (await codec.getNextFrame()).image;
      codec.dispose();
      final output = (await result.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      result.dispose();
      expect(output.getUint32(0), 0);
      expect(output.getUint32((2 * 5 + 2) * 4), 0xffffffff);
      expect(output.getUint32((1 * 5 + 1) * 4), 0xff0000ff);
    },
  );

  test('restaurar o fundo preserva o original e o enquadramento', () {
    final hash = List.filled(64, 'a').join();
    final cutout = List.filled(64, 'b').join();
    final original = NotebookPicture(
      hash: hash,
      cutoutHash: cutout,
      caption: 'Retrato',
      extra: const {
        'look': {'size': 0.5, 'x': -1, 'border': true},
      },
    );
    final restored = NotebookPicture.fromJson(
      original.edit(caption: 'Retrato', afterParagraph: 1).toJson(),
    );
    expect(restored.displayedHash, hash);
    expect(restored.cutoutHash, isNull);
    expect(restored.layout.size, 0.5);
    expect(restored.layout.x, -1);
    expect(restored.extra['look']['border'], isTrue);
  });
}
