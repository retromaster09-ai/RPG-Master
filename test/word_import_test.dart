import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rpg_master_set/campaigns.dart';
import 'package:rpg_master_set/word_import_screen.dart';
import 'package:rpg_master_set/missions.dart';
import 'package:rpg_master_set/word_import.dart';

Uint8List document(String body, {bool image = false}) =>
    ZipEncoder().encodeBytes(
      Archive()
        ..addFile(
          ArchiveFile.string('word/document.xml', '''
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body>$body</w:body></w:document>'''),
        )
        ..addFile(ArchiveFile.string('[Content_Types].xml', '<Types/>'))
        ..addFile(
          ArchiveFile.string(
            image ? 'word/media/image1.png' : 'word/styles.xml',
            '',
          ),
        ),
    );

String paragraph(
  String text, {
  String properties = '',
  String runProperties = '',
}) => '<w:p>$properties<w:r>$runProperties<w:t>$text</w:t></w:r></w:p>';

String heading(String title) =>
    paragraph(title, properties: '<w:pPr><w:pStyle w:val="Ttulo1"/></w:pPr>');

String table(List<List<String>> rows) =>
    '<w:tbl>${rows.map((cells) => '<w:tr>${cells.map((c) => '<w:tc>${paragraph(c)}</w:tc>').join()}</w:tr>').join()}</w:tbl>';

void main() {
  test('reconhece missões com etapas, tabelas e crônicas de várias datas', () {
    final preview = readWordDocument(
      document(
        [
          heading('Mapa do caderno'),
          paragraph('Leia estas instruções.'),
          heading('01 • Objetivos, Missões e Quests'),
          paragraph(
            'þ Recuperar o selo',
            runProperties: '<w:rPr><w:rFonts w:ascii="Wingdings"/></w:rPr>',
          ),
          paragraph(
            '☐ Abrir o baú: Chave da torre',
            properties: '<w:pPr><w:ind w:left="720"/></w:pPr>',
          ),
          paragraph('□ Objetivo de reserva'),
          heading('02 • Mistérios e pistas'),
          paragraph('☑ Quem estava lá?'),
          paragraph(
            'Um guarda viu a carruagem.',
            properties: '<w:pPr><w:ind w:left="720"/></w:pPr>',
          ),
          heading('03 • Pessoas importantes'),
          table([
            ['NPC', 'O que sabemos'],
            ['Guia', 'Conhece a costa'],
          ]),
          heading('04 • Lugares importantes'),
          table([
            ['Local', 'Descrição'],
            ['Torre', 'Vista da praia'],
          ]),
          heading('05 • Relíquias, objetos e sinais'),
          table([
            ['Item / sinal', 'Registro', 'Estado'],
            ['Selo', 'Está escondido', 'Em busca'],
          ]),
          heading('06 • Mural de hipóteses'),
          table([
            ['Hipótese', 'Evidências'],
            ['O selo abre a torre', 'Um símbolo na porta'],
          ]),
          heading('07 • Crônica da campanha'),
          paragraph('16/09/2025 e 23/09/2025 — Chegamos à costa.'),
          paragraph('A mesa cruzou a ponte.'),
          paragraph('06/10/2025 a 23/10/2025 — Trecho sem datas precisas.'),
        ].join(),
        image: true,
      ),
    );
    expect(preview.hasImages, isTrue);
    final rows = preview.records;
    final mission = rows.firstWhere((row) => row.title == 'Recuperar o selo');
    expect(mission.mission!.status, MissionStatus.completed);
    expect(mission.mission!.steps.single.title, 'Abrir o baú');
    expect(mission.mission!.steps.single.completed, isFalse);
    expect(mission.mission!.steps.single.details, 'Chave da torre');
    expect(
      rows.singleWhere((row) => row.title == 'Quem estava lá?').answer,
      'Um guarda viu a carruagem.',
    );
    expect(
      rows.singleWhere((row) => row.category == 'Personagem').title,
      'Guia',
    );
    expect(rows.singleWhere((row) => row.category == 'Lugar').title, 'Torre');
    expect(
      rows.singleWhere((row) => row.category == 'Objeto').body,
      contains('Estado: Em busca'),
    );
    expect(
      rows.singleWhere((row) => row.title == 'O selo abre a torre').confidence,
      'Hipótese',
    );
    final session = rows.singleWhere((row) => row.category == 'Sessão');
    expect(session.dates, [
      '2025-09-16T00:00:00.000Z',
      '2025-09-23T00:00:00.000Z',
    ]);
    expect(session.body, 'Chegamos à costa.\n\nA mesa cruzou a ponte.');
    expect(
      rows.where((row) => row.category == null).last.body,
      contains('06/10/2025 a 23/10/2025'),
    );
    expect(
      rows.where((row) => row.category == null).first.body,
      contains('Leia estas instruções.'),
    );
  });

  testWidgets(
    'a prévia salva somente quando confirmada e deixa trechos ambíguos desmarcados',
    (tester) async {
      const known = CampaignRecord(
        'A ponte',
        'Perto da torre',
        id: 'known',
        category: 'Lugar',
      );
      const duplicate = CampaignRecord(
        'A ponte',
        'Perto da torre',
        id: 'copy',
        category: 'Lugar',
      );
      const available = CampaignRecord(
        'Guarda',
        'Na vila',
        id: 'new',
        category: 'Personagem',
      );
      const review = CampaignRecord(
        'Trecho de abertura',
        'Texto livre',
        id: 'review',
      );
      List<CampaignRecord>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: WordImportScreen(
            campaign: const Campaign(
              id: 'mesa',
              name: 'Mesa de teste',
              ownerId: 'mestre',
            ),
            notebook: Notebook.fromRpc({
              'epoch': 0,
              'revision': 1,
              'entries': [known.toJson()],
            }),
            preview: const WordImportPreview([
              duplicate,
              available,
              review,
            ], hasImages: false),
            onClose: () {},
            onImport: (rows) async => saved = rows,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.text('Importar 1 para a campanha'), findsOneWidget);
      await tester.tap(find.text('Limpar seleção'));
      await tester.pumpAndSettle();
      expect(find.text('Importar 0 para a campanha'), findsOneWidget);
      await tester.tap(find.text('Selecionar sugestões'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Importar 1 para a campanha'));
      await tester.pumpAndSettle();
      expect(saved, [available]);
    },
  );

  test('rejeita arquivos inválidos e datas impossíveis', () {
    expect(
      () => readWordDocument(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    expect(readWordDates('29/02/2025'), isNull);
    expect(readWordDates('1/6/2026, 2026-06-02'), [
      '2026-06-01T00:00:00.000Z',
      '2026-06-02T00:00:00.000Z',
    ]);
  });
}
