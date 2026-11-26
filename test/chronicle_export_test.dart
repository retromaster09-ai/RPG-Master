import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rpg_master_set/campaigns.dart';
import 'package:rpg_master_set/chronicle_export.dart';
import 'package:rpg_master_set/cover_picker.dart';
import 'package:rpg_master_set/notebook_format.dart';

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAI'
  'AAAABCAIAAAB7QOjdAAAAD0lEQVR4nGM0Cq5gYGAAAAS5AP+m9miSAAAAAElFTkSuQmCC',
);
Future<Uint8List> _image(String hash) async => _pixel;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'envia PDF e PNG ao compartilhamento nativo quando solicitado',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const channel = MethodChannel('rpg_master_set/chronicle_export');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final received = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        received.add(call);
        return true;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = null;
      });
      await saveChronicleFile(
        _pixel,
        'cronicas.pdf',
        'application/pdf',
        action: ChronicleExportAction.share,
      );
      await saveChronicleFile(
        _pixel,
        'cronica.png',
        'image/png',
        action: ChronicleExportAction.share,
      );
      await saveChronicleFile(_pixel, 'cronica.png', 'image/png');
      expect(received.map((call) => call.method), [
        'shareFile',
        'shareFile',
        'saveFile',
      ]);
      expect(received[0].arguments['mimeType'], 'application/pdf');
      expect(received[1].arguments['name'], 'cronica.png');
    },
  );

  test(
    'gera PDF com todas as crônicas e pagina um texto longo com imagens',
    () async {
      final first = CampaignRecord(
        'A praça',
        List.filled(240, 'A mesa prosseguiu até a fortaleza.').join(' '),
        category: 'Sessão',
        dates: const ['2026-01-01T00:00:00.000Z'],
        presentation: const NotebookPresentation(
          paper: NotebookPaper.parchment,
          pictures: [NotebookPicture(hash: 'test', caption: 'Mapa')],
        ),
      );
      const second = CampaignRecord(
        'A torre',
        'Entraram e fecharam a porta.',
        category: 'Sessão',
      );
      final pdf = await exportChroniclesPdf('Mesa', [first, second], _image);
      final raw = latin1.decode(pdf);
      expect(raw, startsWith('%PDF-'));
      expect(RegExp(r'/Type\s*/Page\b').allMatches(raw).length, greaterThan(2));
    },
  );

  test('preserva a resolução de uma imagem de crônica importada', () async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xffaa6655), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final original = await picture.toImage(2000, 1000);
    picture.dispose();
    final data = await original.toByteData(format: ui.ImageByteFormat.png);
    original.dispose();

    final prepared = await prepareCoverImage(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      maxSide: 2200,
      maxPngBytes: 3 * 1024 * 1024,
    );
    final codec = await ui.instantiateImageCodec(prepared);
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    expect(image.width, 2000);
    expect(image.height, 1000);
    image.dispose();
  });

  test('exporta uma crônica curta em PNG com 1740 px de largura', () async {
    final png = await exportChroniclePng(
      const CampaignRecord('O farol', 'A mesa encontrou a carta.'),
      _image,
    );
    final codec = await ui.instantiateImageCodec(png);
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    expect(image.width, 1740);
    image.dispose();
  });

  test('gera PNG com o texto além da altura de uma tela', () async {
    final chronicle = CampaignRecord(
      'A praça',
      List.filled(80, 'A mesa prosseguiu.').join('\n\n'),
      category: 'Sessão',
      coverHash: 'test',
    );
    final png = await exportChroniclePng(chronicle, _image);
    expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final codec = await ui.instantiateImageCodec(png);
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    expect(image.height, greaterThan(1300));
    image.dispose();
  });
}
