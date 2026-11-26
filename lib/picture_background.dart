import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;

enum PictureBackground {
  automatic('Automático pelas bordas'),
  white('Branco'),
  black('Preto'),
  green('Verde');

  const PictureBackground(this.label);
  final String label;
}

Future<Uint8List> removePictureBackground(
  Uint8List png,
  PictureBackground background,
  int tolerance,
) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(png);
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (width, height) {
      final largest = max(width, height);
      const maxSide = 2200;
      if (largest <= maxSide) return const ui.TargetImageSize();
      return ui.TargetImageSize(
        width: max(1, (width * maxSide / largest).round()),
        height: max(1, (height * maxSide / largest).round()),
      );
    },
  );
  final ui.Image image;
  try {
    image = (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) {
      throw const FormatException('Não foi possível ler a imagem.');
    }
    final (width, height) = (image.width, image.height);
    final pixels = await compute(_cutout, (
      pixels: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      width: width,
      height: height,
      background: background,
      tolerance: tolerance,
    ));
    final result = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      result.complete,
    );
    final transparent = await result.future;
    try {
      final encoded = await transparent.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (encoded == null) {
        throw const FormatException('Não foi possível guardar o recorte.');
      }
      return encoded.buffer.asUint8List(
        encoded.offsetInBytes,
        encoded.lengthInBytes,
      );
    } finally {
      transparent.dispose();
    }
  } finally {
    image.dispose();
  }
}

typedef _Pixels = ({
  Uint8List pixels,
  int width,
  int height,
  PictureBackground background,
  int tolerance,
});
typedef _Rgb = ({int red, int green, int blue});

int _distance(_Rgb a, _Rgb b) {
  final dr = a.red - b.red;
  final dg = a.green - b.green;
  final db = a.blue - b.blue;
  return dr * dr + dg * dg + db * db;
}

_Rgb _color(Uint8List rgba, int offset) {
  final alpha = rgba[offset + 3];
  int channel(int index) => (rgba[offset + index] * 255 + alpha ~/ 2) ~/ alpha;
  return (red: channel(0), green: channel(1), blue: channel(2));
}

_Rgb _edgeColor(_Pixels input) {
  final samples = <_Rgb>[];
  for (var index = 0; index <= 12; index++) {
    final x = (input.width - 1) * index ~/ 12;
    final y = (input.height - 1) * index ~/ 12;
    for (final pixel in [
      x,
      (input.height - 1) * input.width + x,
      y * input.width,
      y * input.width + input.width - 1,
    ]) {
      final offset = 4 * pixel;
      if (input.pixels[offset + 3] >= 200) {
        samples.add(_color(input.pixels, offset));
      }
    }
  }
  var selected = (red: 255, green: 255, blue: 255);
  var most = 0;
  for (final sample in samples) {
    final matches = samples
        .where((other) => _distance(sample, other) <= 28 * 28 * 3)
        .length;
    if (matches > most) {
      selected = sample;
      most = matches;
    }
  }
  return selected;
}

Uint8List _cutout(_Pixels input) {
  final (width, height) = (input.width, input.height);
  final rgba = input.pixels;
  final target = switch (input.background) {
    PictureBackground.automatic => _edgeColor(input),
    PictureBackground.white => (red: 255, green: 255, blue: 255),
    PictureBackground.black => (red: 0, green: 0, blue: 0),
    PictureBackground.green => (red: 0, green: 255, blue: 0),
  };
  final limit = input.tolerance * input.tolerance * 3;
  final count = width * height;
  final queue = Uint32List(count);
  final visited = Uint8List(count);
  var head = 0;
  var tail = 0;
  var removed = 0;

  void visit(int pixel) {
    if (visited[pixel] != 0) return;
    visited[pixel] = 1;
    final offset = pixel * 4;
    final alpha = rgba[offset + 3];
    if (alpha != 0 && _distance(_color(rgba, offset), target) > limit) return;
    if (alpha != 0) removed++;
    rgba.fillRange(offset, offset + 4, 0);
    queue[tail++] = pixel;
  }

  for (var x = 0; x < width; x++) {
    visit(x);
    visit((height - 1) * width + x);
  }
  for (var y = 0; y < height; y++) {
    visit(y * width);
    visit(y * width + width - 1);
  }
  while (head < tail) {
    final pixel = queue[head++];
    final x = pixel % width;
    if (x > 0) visit(pixel - 1);
    if (x + 1 < width) visit(pixel + 1);
    if (pixel >= width) visit(pixel - width);
    if (pixel + width < count) visit(pixel + width);
  }
  if (removed == 0) {
    throw const FormatException(
      'Nenhum fundo dessa cor foi encontrado nas bordas.',
    );
  }
  for (var offset = 3; offset < rgba.length; offset += 4) {
    if (rgba[offset] != 0) return rgba;
  }
  throw const FormatException(
    'O ajuste deixaria a imagem toda transparente. Reduza a tolerância.',
  );
}
