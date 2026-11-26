import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:diacritic/diacritic.dart';
import 'package:xml/xml.dart';

import 'campaigns.dart';
import 'missions.dart';
import 'session_dates.dart';

const maxWordFileBytes = 12 * 1024 * 1024;
const _maxXmlBytes = 4 * 1024 * 1024;

const wordImportSections = {
  'Missão': 'Objetivos e missões',
  'Investigação': 'Mistérios e pistas',
  'Personagem': 'Pessoas importantes',
  'Lugar': 'Lugares importantes',
  'Objeto': 'Relíquias, objetos e sinais',
  'Carta': 'Cartas',
  'Sessão': 'Crônicas',
};

class WordImportPreview {
  const WordImportPreview(this.records, {required this.hasImages});
  final List<CampaignRecord> records;
  final bool hasImages;
}

WordImportPreview readWordDocument(Uint8List bytes) {
  if (bytes.length > maxWordFileBytes) {
    throw const FormatException('Escolha um documento de até 12 MB.');
  }
  try {
    final headers = ZipDirectory().headers(
      InputMemoryStream(bytes),
      verify: true,
    );
    ZipFileHeader? main;
    var hasImages = false;
    for (final header in headers) {
      if (header.filename == 'word/document.xml') {
        if (main != null) {
          throw const FormatException('O arquivo Word está inválido.');
        }
        main = header;
      }
      if (header.filename.startsWith('word/media/')) hasImages = true;
    }
    if (main == null) {
      throw const FormatException(
        'O arquivo precisa ser um documento .docx válido.',
      );
    }
    if (main.uncompressedSize > _maxXmlBytes) {
      throw const FormatException(
        'O texto do documento é grande demais. Divida o Word em arquivos menores.',
      );
    }
    final file = main.file!;
    if (file.flags & 1 != 0) {
      throw const FormatException(
        'Escolha um arquivo Word sem proteção por senha.',
      );
    }
    if (file.compressionMethod != CompressionType.deflate &&
        file.compressionMethod != CompressionType.none) {
      throw const FormatException(
        'O formato interno do arquivo Word não é compatível.',
      );
    }
    final output = _WordXmlBuffer();
    file.decompress(output);
    final xml = XmlDocument.parse(utf8.decode(output.getBytes()));
    final rootNamespace = xml.rootElement.name.namespaceUri;
    if (xml.doctypeElement != null ||
        xml.rootElement.name.local != 'document' ||
        (rootNamespace !=
                'http://schemas.openxmlformats.org/wordprocessingml/2006/main' &&
            rootNamespace !=
                'http://purl.oclc.org/ooxml/wordprocessingml/main')) {
      throw const FormatException(
        'A estrutura do documento Word não é compatível.',
      );
    }
    final body = _child(xml.rootElement, 'body');
    if (body == null) {
      throw const FormatException('O documento Word está vazio.');
    }
    final records = _NotebookWordReader().read(body);
    if (records.isEmpty) {
      throw const FormatException('Nenhum texto importável foi encontrado.');
    }
    return WordImportPreview(records, hasImages: hasImages);
  } on FormatException {
    rethrow;
  } on Exception {
    throw const FormatException(
      'Não foi possível ler o Word. Confira se o arquivo abre normalmente.',
    );
  } on RangeError {
    throw const FormatException('O arquivo Word está incompleto ou inválido.');
  }
}

// Limit the real decompressed size even when a ZIP entry misstates its size.
class _WordXmlBuffer extends OutputMemoryStream {
  void _check(int count) {
    if (count > _maxXmlBytes) {
      throw const FormatException('O texto do documento é grande demais.');
    }
  }

  @override
  void reserve(int total) {
    _check(total);
    super.reserve(total);
  }

  @override
  void writeByte(int value) {
    _check(length + 1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _check(this.length + (length ?? bytes.length));
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeBackReference(int distance, int count) {
    _check(length + count);
    super.writeBackReference(distance, count);
  }

  @override
  void writeStream(InputStream stream) {
    _check(length + stream.length);
    super.writeStream(stream);
  }
}

Iterable<XmlElement> _children(XmlElement? parent, String name) =>
    parent?.childElements.where((e) => e.name.local == name) ?? const [];

XmlElement? _child(XmlElement? parent, String name) =>
    _children(parent, name).firstOrNull;

String? _attr(XmlElement? element, String name) =>
    element?.attributes.where((a) => a.name.local == name).firstOrNull?.value;

String _normalize(String input) =>
    removeDiacritics(input.toLowerCase())
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

String _headingName(String input) =>
    _normalize(input).replaceFirst(RegExp(r'^[^a-z]+'), '');

String? _sectionCategory(String text) {
  final value = _headingName(text);
  if (value.length > 95) return null;
  if (RegExp(r'^(objetivos?|missoes|quests)\b').hasMatch(value)) {
    return 'Missão';
  }
  if (RegExp(
    r'^(misterios|investigacoes|perguntas|pistas|teorias|hipoteses|mural de hipoteses)\b',
  ).hasMatch(value)) {
    return 'Investigação';
  }
  if (RegExp(r'^(pessoas|personagens|npcs)\b').hasMatch(value)) {
    return 'Personagem';
  }
  if (RegExp(r'^(lugares|locais)\b').hasMatch(value)) return 'Lugar';
  if (RegExp(r'^(reliquias|objetos|itens|sinais)\b').hasMatch(value)) {
    return 'Objeto';
  }
  if (RegExp(r'^cartas\b').hasMatch(value)) return 'Carta';
  if (RegExp(r'^(cronicas?|cronologia|resumos das sessoes|sessoes)\b')
      .hasMatch(value)) {
    return 'Sessão';
  }
  return null;
}

class _WordParagraph {
  _WordParagraph(XmlElement element) {
    final properties = _child(element, 'pPr');
    final style = _normalize(_attr(_child(properties, 'pStyle'), 'val') ?? '');
    final outline = _attr(_child(properties, 'outlineLvl'), 'val');
    heading =
        (int.tryParse(outline ?? '') ?? 9) < 9 ||
        RegExp(r'^(heading|titulo|ttulo)[1-9]$').hasMatch(style);
    final level =
        int.tryParse(
          _attr(_child(_child(properties, 'numPr'), 'ilvl'), 'val') ?? '',
        ) ??
        0;
    final indent = _child(properties, 'ind');
    final left =
        int.tryParse(_attr(indent, 'start') ?? _attr(indent, 'left') ?? '') ??
        0;
    depth = left > 0 ? left : level * 720;
    listed =
        level > 0 ||
        _child(properties, 'numPr') != null ||
        style.contains('marcador') ||
        style.contains('lista');
    final textBuffer = StringBuffer();
    void visit(XmlElement node, {bool wingdings = false}) {
      switch (node.name.local) {
        case 'del' || 'instrText' || 'drawing' || 'pict' || 'txbxContent':
          return;
        case 'r':
          final fonts = _child(_child(node, 'rPr'), 'rFonts');
          wingdings = (_attr(fonts, 'ascii') ?? _attr(fonts, 'hAnsi') ?? '')
              .toLowerCase()
              .contains('wingdings');
        case 't':
          final value = node.innerText;
          textBuffer.write(
            wingdings
                ? value
                      .replaceAll('þ', '☑')
                      .replaceAll('\u00fc', '☑')
                      .replaceAll('\uf0fe', '☑')
                      .replaceAll('\uf0a8', '☐')
                : value,
          );
          return;
        case 'sym':
          if ((_attr(node, 'font') ?? '').toLowerCase().contains('wingdings')) {
            final code = (_attr(node, 'char') ?? '').toLowerCase();
            if (const ['f0fe', 'f0fc', '00fe', '00fc'].contains(code)) {
              textBuffer.write('☑');
            }
            if (const ['f0a8', '00a8'].contains(code)) textBuffer.write('☐');
          }
          return;
        case 'tab':
          textBuffer.write('\t');
          return;
        case 'br' || 'cr':
          textBuffer.write('\n');
          return;
      }
      for (final child in node.childElements) {
        visit(child, wingdings: wingdings);
      }
    }

    visit(element);
    final raw = textBuffer.toString().trim();
    final box = RegExp(r'^(☐|□|☑|☒|✓|✔|\[[ xX]\])\s*').firstMatch(raw);
    if (box != null) {
      checked = !const ['☐', '□', '[ ]'].contains(box[1]);
      text = raw.substring(box.end).trimLeft();
    } else {
      final checkbox = element.descendantElements
          .where(
            (e) => e.name.local == 'checkbox' || e.name.local == 'checkBox',
          )
          .firstOrNull;
      final value = _attr(_child(checkbox, 'checked'), 'val');
      if (checkbox != null) {
        checked = value == '1' || value == 'true' || value == 'on';
      }
      text = raw;
    }
  }

  late final String text;
  late final bool heading;
  late final bool listed;
  late final int depth;
  bool? checked;
}

final _wordDate = RegExp(r'\d{1,2}/\d{1,2}/\d{4}|\d{4}-\d{2}-\d{2}');
final _dateList = RegExp(
  r'^\s*(?:\d{1,2}/\d{1,2}/\d{4}|\d{4}-\d{2}-\d{2})(?:\s*(?:,|\be\b|&)\s*(?:\d{1,2}/\d{1,2}/\d{4}|\d{4}-\d{2}-\d{2}))*',
  caseSensitive: false,
);

List<String>? readWordDates(String value) {
  final input = value.trim();
  if (input.isEmpty) return const [];
  final found = _dateList.firstMatch(input);
  if (found == null || found.end != input.length) return null;
  final dates = <String>{};
  for (final match in _wordDate.allMatches(input)) {
    final date = match[0]!;
    final fields = date.contains('/')
        ? date.split('/').reversed.toList()
        : date.split('-');
    final day = sessionDay(
      '${fields[0]}-${fields[1].padLeft(2, '0')}-${fields[2].padLeft(2, '0')}T',
    );
    if (day == null) return null;
    dates.add(sessionDateValue(day));
  }
  return dates.toList()..sort();
}

class _DraftRow {
  _DraftRow(
    this.category,
    this.title, {
    this.hypothesis = false,
    this.checked,
    this.depth = 0,
    this.dates = const [],
  });

  final String? category;
  final String title;
  final bool hypothesis;
  final bool? checked;
  final int depth;
  final List<String> dates;
  final lines = <String>[];
  final answers = <String>[];
  final steps = <MissionStep>[];
  int lastStepDepth = -1;

  CampaignRecord record() => CampaignRecord(
    title,
    lines.join('\n\n'),
    id: newNotebookRecordId(),
    category: category,
    answer: answers.join('\n\n'),
    confidence: hypothesis ? 'Hipótese' : null,
    dates: dates,
    mission: category == 'Missão'
        ? MissionPlan(
            completed: checked == true,
            started: checked == true || steps.any((step) => step.completed),
            steps: steps,
          )
        : null,
  );
}

class _NotebookWordReader {
  final records = <CampaignRecord>[];
  _DraftRow? _row;
  String? _section;
  bool _hypothesis = false;

  List<CampaignRecord> read(XmlElement body) {
    for (final block in body.childElements) {
      switch (block.name.local) {
        case 'p':
          _paragraph(_WordParagraph(block));
        case 'tbl':
          _table(block);
        case 'sdt':
          final nested = _child(block, 'sdtContent');
          if (nested != null) {
            for (final item in _children(nested, 'p')) {
              _paragraph(_WordParagraph(item));
            }
          }
      }
    }
    _flush();
    return records;
  }

  void _flush() {
    if (_row case final row?) records.add(row.record());
    _row = null;
  }

  void _paragraph(_WordParagraph p) {
    final text = p.text;
    if (text.isEmpty ||
        RegExp(r'^[\p{P}\p{S}\s]+$', unicode: true).hasMatch(text)) {
      return;
    }
    final proposed = _sectionCategory(text);
    final simpleSection = RegExp(
      r'^(?:\d{1,2}\b|objetivos e missoes$|mural de hipoteses$|cronica da campanha$|pessoas importantes$|lugares importantes$|cartas$)',
    ).hasMatch(_normalize(text).replaceFirst(RegExp(r'^[^a-z0-9]+'), ''));
    if (p.heading ||
        (simpleSection && proposed != null && !p.listed && p.checked == null)) {
      _flush();
      if (proposed != null) {
        _section = proposed;
        _hypothesis = RegExp(r'^(teorias|hipoteses|mural de hipoteses)\b')
            .hasMatch(_headingName(text));
      } else if (_section != null) {
        _row = _DraftRow(_section, text, hypothesis: _hypothesis);
      } else {
        _row = _DraftRow(null, text);
      }
      return;
    }

    if (_section == 'Sessão') {
      final prefix = _dateList.firstMatch(text);
      if (prefix != null) {
        _flush();
        final dateText = prefix[0]!.trim();
        final possibleRange = RegExp(
          r'^\s*(?:a|até)\s+\d',
          caseSensitive: false,
        ).hasMatch(text.substring(prefix.end));
        final dates = possibleRange ? null : readWordDates(dateText);
        _row = _DraftRow(
          dates == null ? null : 'Sessão',
          'Sessão de $dateText',
          dates: dates ?? const [],
        );
        final content = dates == null
            ? text
            : text
                  .substring(prefix.end)
                  .replaceFirst(RegExp(r'^\s*[:–—-]?\s*'), '');
        if (content.isNotEmpty) _row!.lines.add(content);
      } else {
        (_row ??= _DraftRow(
          null,
          'Trecho da crônica sem data',
        )).lines.add(text);
      }
      return;
    }

    final current = _row;
    if (_section == 'Missão') {
      if (current != null && p.depth > current.depth) {
        if (p.checked != null) {
          current.lastStepDepth = p.depth;
          final (title, detail) = _splitTitle(text);
          current.steps.add(
            MissionStep.fromJson({
              'title': title,
              'details': detail,
              'completed': p.checked == true,
            }),
          );
        } else if (current.steps.isNotEmpty &&
            p.depth >= current.lastStepDepth) {
          final last = current.steps.last;
          current.steps[current.steps.length - 1] = last.copyWith(
            details: [
              last.details,
              text,
            ].where((line) => line.isNotEmpty).join('\n'),
          );
        } else {
          current.lines.add(text);
        }
      } else if (current != null && p.checked == null && !p.listed) {
        current.lines.add(text);
      } else {
        _flush();
        final (title, detail) = _splitTitle(text);
        _row = _DraftRow(_section, title, checked: p.checked, depth: p.depth);
        if (detail.isNotEmpty) _row!.lines.add(detail);
      }
      return;
    }

    if (current != null && p.depth > current.depth) {
      if (current.checked == true &&
          _section == 'Investigação' &&
          !_hypothesis) {
        current.answers.add(text);
      } else {
        current.lines.add(text);
      }
    } else if (_section != null &&
        (p.listed || p.checked != null || current == null)) {
      _flush();
      final (title, detail) = _splitTitle(text);
      _row = _DraftRow(
        _section,
        title,
        hypothesis: _hypothesis,
        checked: p.checked,
        depth: p.depth,
      );
      if (detail.isNotEmpty) _row!.lines.add(detail);
    } else {
      (_row ??= _DraftRow(null, 'Trecho sem seção')).lines.add(text);
    }
  }

  void _table(XmlElement table) {
    _flush();
    final rows = [
      for (final row in _children(table, 'tr'))
        [
          for (final cell in _children(row, 'tc'))
            _children(cell, 'p')
                .map((p) => _WordParagraph(p).text)
                .where((text) => text.isNotEmpty)
                .join('\n'),
        ],
    ].where((row) => row.any((cell) => cell.isNotEmpty)).toList();
    if (rows.isEmpty) return;
    final header = rows.first.map(_normalize).toList();
    final hasHeader =
        header.length >= 2 &&
        RegExp(
          r'^(npc|nome|personagem|local|lugar|item|reliquia|objeto|sinal|pista|carta|hipotese|pergunta|titulo|secao)\b',
        ).hasMatch(header.first);
    final hypothesis = _hypothesis || header.first.startsWith('hipotese');
    // A one-cell callout or an unknown table stays available for review.
    if (_section == null || header.length == 1 || _section == 'Sessão') {
      final row = _DraftRow(null, 'Tabela do documento')
        ..lines.addAll(
          rows.map(
            (cells) => cells.where((cell) => cell.isNotEmpty).join(' · '),
          ),
        );
      records.add(row.record());
      return;
    }
    for (final cells in rows.skip(hasHeader ? 1 : 0)) {
      final title = cells.first;
      final row = _DraftRow(
        title.isEmpty ? null : _section,
        title.isEmpty ? 'Linha sem título' : title,
        hypothesis: hypothesis,
      );
      for (var index = 1; index < cells.length; index++) {
        if (cells[index].isEmpty) continue;
        row.lines.add(
          index > 1 && hasHeader && index < rows.first.length
              ? '${rows.first[index]}: ${cells[index]}'
              : cells[index],
        );
      }
      records.add(row.record());
    }
  }
}

(String, String) _splitTitle(String text) {
  final split = RegExp(r'(?:: |\s+[–—]\s+|\n)').firstMatch(text);
  if (split != null && split.start > 0 && split.start < 150) {
    return (
      text.substring(0, split.start).trim(),
      text.substring(split.end).trim(),
    );
  }
  return (text, '');
}
