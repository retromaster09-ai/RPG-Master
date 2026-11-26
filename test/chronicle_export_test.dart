import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_master_set/campaigns.dart';
import 'package:rpg_master_set/chronicle_export.dart';
import 'package:rpg_master_set/notebook_format.dart';

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAI'
  'AAAABCAIAAAB7QOjdAAAAD0lEQVR4nGM0Cq5gYGAAAAS5AP+m9miSAAAAAElFTkSuQmCC',
);
Future<Uint8List> _image(String hash) async => _pixel;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
