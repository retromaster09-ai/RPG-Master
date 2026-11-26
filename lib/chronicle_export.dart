import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:diacritic/diacritic.dart';
import 'package:flutter/foundation.dart'
    show Uint8List, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_selector/file_selector.dart' as files;
import 'package:material_ui/material_ui.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'campaigns.dart';
import 'notebook_format.dart';
import 'notebook_rich_text.dart';
import 'session_dates.dart';

typedef ChronicleImageReader = Future<Uint8List> Function(String hash);

String chronicleFileName(String title, String extension) {
  final name = removeDiacritics(title.toLowerCase())
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final trimmed = name.length <= 70 ? name : name.substring(0, 70);
  return '${trimmed.isEmpty ? 'cronica' : trimmed}.$extension';
}

Future<void> shareChronicleFile(
  Uint8List bytes,
  String name,
  String mimeType, {
  required Rect origin,
}) async {
  final file = XFile.fromData(bytes, name: name, mimeType: mimeType);
  if (!kIsWeb &&
      const {
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      }.contains(defaultTargetPlatform)) {
    final location = await files.getSaveLocation(suggestedName: name);
    if (location != null) await file.saveTo(location.path);
    return;
  }
  await SharePlus.instance.share(
    ShareParams(
      files: [file],
      fileNameOverrides: [name],
      sharePositionOrigin: origin,
    ),
  );
}

sealed class _Block {
  const _Block();
}

class _Words extends _Block {
  const _Words(this.span);
  final TextSpan span;
}

class _Illustration extends _Block {
  const _Illustration(this.data, this.layout);
  final Uint8List data;
  final PictureLayout layout;
}

typedef _PaperStyle = ({Color surface, Color ink, String family, bool light});

_PaperStyle _paper(NotebookPaper style, {required bool lightPlain}) =>
    switch (style) {
      NotebookPaper.plain => (
        surface: lightPlain ? const Color(0xfffdfaf6) : const Color(0xff1b1612),
        ink: lightPlain ? const Color(0xff29221e) : const Color(0xfff7e8d3),
        family: 'Crimson Text',
        light: lightPlain,
      ),
      NotebookPaper.parchment => (
        surface: const Color(0xfff4dfae),
        ink: const Color(0xff3f2818),
        family: 'RpgScript',
        light: true,
      ),
      NotebookPaper.diary => (
        surface: const Color(0xffead0a7),
        ink: const Color(0xff48261e),
        family: 'Crimson Text',
        light: true,
      ),
      NotebookPaper.future => (
        surface: const Color(0xff142736),
        ink: const Color(0xffceeeff),
        family: 'RpgMono',
        light: false,
      ),
    };

Future<List<_Block>> _chronicleBlocks(
  CampaignRecord chronicle,
  _PaperStyle paper,
  ChronicleImageReader readImage,
) async {
  final presentation = chronicle.presentation;
  final body = TextStyle(
    color: paper.ink,
    fontFamily: paper.family,
    fontSize: 14,
    height: 1.35,
  );
  final heading = body.copyWith(
    fontSize: 27,
    height: 1.15,
    fontWeight: FontWeight.bold,
  );
  final blocks = <_Block>[
    _Words(
      TextSpan(
        text: chronicle.title.isEmpty ? 'Crônica' : chronicle.title,
        style: heading,
      ),
    ),
    if (chronicle.dates.isNotEmpty)
      _Words(
        TextSpan(
          text: chronicle.dates.map(sessionDateLabel).join(' · '),
          style: body,
        ),
      ),
    if (chronicle.coverHash case final cover?)
      _Illustration(await readImage(cover), const PictureLayout()),
  ];
  final paragraphs = notebookParagraphs(chronicle.body);
  final pictures = <int, List<NotebookPicture>>{};
  for (final picture in presentation.pictures) {
    if (picture.displayedHash == null) continue;
    final position = picture.afterParagraph.clamp(-1, paragraphs.length - 1);
    pictures.putIfAbsent(position, () => []).add(picture);
  }

  Future<void> appendPictures(int position) async {
    for (final picture in pictures[position] ?? const <NotebookPicture>[]) {
      blocks.add(
        _Illustration(await readImage(picture.displayedHash!), picture.layout),
      );
      if (picture.caption.isNotEmpty) {
        blocks.add(
          _Words(
            TextSpan(
              text: picture.caption,
              style: body.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        );
      }
    }
  }

  await appendPictures(-1);
  for (final (index, paragraph) in paragraphs.indexed) {
    blocks.add(
      _Words(
        notebookTextSpan(
          chronicle.body.substring(paragraph.start, paragraph.end),
          sliceNotebookMarks(
            presentation.bodyMarks,
            paragraph.start,
            paragraph.end,
          ),
          body,
          lightPaper: paper.light,
        ),
      ),
    );
    await appendPictures(index);
  }
  if (chronicle.answer.isNotEmpty) {
    blocks.add(
      _Words(
        TextSpan(
          text: 'Resposta',
          style: body.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
    blocks.add(
      _Words(
        notebookTextSpan(
          chronicle.answer,
          presentation.answerMarks,
          body,
          lightPaper: paper.light,
        ),
      ),
    );
  }
  return blocks;
}

Future<Uint8List> exportChroniclesPdf(
  String campaignName,
  List<CampaignRecord> chronicles,
  ChronicleImageReader readImage,
) async {
  final document = pw.Document(title: 'Crônicas · $campaignName');
  final fonts = <String, Future<_PdfFonts>>{};
  for (final chronicle in chronicles) {
    final paper = _paper(chronicle.presentation.paper, lightPlain: true);
    final textFonts = await fonts.putIfAbsent(
      paper.family,
      () => _pdfFonts(paper.family),
    );
    final blocks = await _chronicleBlocks(chronicle, paper, readImage);
    document.addPage(
      pw.MultiPage(
        maxPages: 1000,
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(42),
          buildBackground: (_) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: _pdfColor(paper.surface)),
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber}',
            style: pw.TextStyle(
              font: textFonts.regular,
              color: _pdfColor(paper.ink),
              fontSize: 9,
            ),
          ),
        ),
        build: (_) => [
          for (final block in blocks) ...[
            switch (block) {
              _Words(:final span) => pw.RichText(
                text: _pdfSpan(span, textFonts),
                overflow: pw.TextOverflow.span,
              ),
              _Illustration(:final data, :final layout) => _pdfImage(
                data,
                layout,
              ),
            },
            pw.SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
  return document.save();
}

pw.Widget _pdfImage(Uint8List data, PictureLayout layout) {
  final size = Size(PdfPageFormat.a4.width - 84, 205);
  final bounds = _imageBounds(Offset.zero & size, layout);
  return pw.SizedBox(
    width: size.width,
    height: size.height,
    child: pw.ClipRect(
      child: pw.Stack(
        children: [
          pw.Positioned(
            left: bounds.left,
            top: bounds.top,
            right: size.width - bounds.right,
            bottom: size.height - bounds.bottom,
            child: pw.Image(
              pw.MemoryImage(data),
              alignment: pw.Alignment(layout.x, -layout.y),
              fit: pw.BoxFit.contain,
            ),
          ),
        ],
      ),
    ),
  );
}

typedef _PdfFonts = ({
  pw.Font regular,
  pw.Font bold,
  pw.Font italic,
  pw.Font boldItalic,
});

Future<_PdfFonts> _pdfFonts(String family) async {
  final base = switch (family) {
    'RpgScript' => 'RpgScript',
    'RpgMono' => 'RpgMono',
    _ => 'CrimsonText',
  };
  Future<pw.Font> load(String variant) async =>
      pw.Font.ttf(await rootBundle.load('assets/fonts/$base-$variant.ttf'));
  return (
    regular: await load('Regular'),
    bold: await load('Bold'),
    italic: await load('Italic'),
    boldItalic: await load('BoldItalic'),
  );
}

PdfColor _pdfColor(Color color) => PdfColor(color.r, color.g, color.b, color.a);

pw.TextSpan _pdfSpan(TextSpan span, _PdfFonts fonts, [TextStyle? parent]) {
  final style = parent?.merge(span.style) ?? span.style ?? const TextStyle();
  final font = switch ((
    style.fontWeight == FontWeight.bold,
    style.fontStyle == FontStyle.italic,
  )) {
    (true, true) => fonts.boldItalic,
    (true, false) => fonts.bold,
    (false, true) => fonts.italic,
    _ => fonts.regular,
  };
  return pw.TextSpan(
    text: span.text,
    style: pw.TextStyle(
      font: font,
      fontSize: style.fontSize,
      color: style.color == null ? null : _pdfColor(style.color!),
      background: style.backgroundColor == null
          ? null
          : pw.BoxDecoration(color: _pdfColor(style.backgroundColor!)),
      lineSpacing: 2,
    ),
    children: [
      for (final child in span.children ?? const <InlineSpan>[])
        if (child is TextSpan) _pdfSpan(child, fonts, style),
    ],
  );
}

Future<Uint8List> exportChroniclePng(
  CampaignRecord chronicle,
  ChronicleImageReader readImage,
) async {
  const width = 580.0;
  const padding = 25.0;
  const gap = 13.0;
  const contentWidth = width - padding * 2;
  final paper = _paper(chronicle.presentation.paper, lightPlain: false);
  final blocks = await _chronicleBlocks(chronicle, paper, readImage);
  final painters = <TextPainter>[];
  final illustrations = <ui.Image>[];
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  var y = padding;
  try {
    for (final block in blocks) {
      switch (block) {
        case _Words(:final span):
          final painter = TextPainter(
            text: span,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: contentWidth);
          painters.add(painter);
          painter.paint(canvas, Offset(padding, y));
          y += painter.height;
        case _Illustration(:final data, :final layout):
          final codec = await ui.instantiateImageCodec(data);
          final ui.Image image;
          try {
            image = (await codec.getNextFrame()).image;
          } finally {
            codec.dispose();
          }
          illustrations.add(image);
          final frame = Rect.fromLTWH(padding, y, contentWidth, 225);
          _paintImage(canvas, image, frame, layout);
          y += frame.height;
      }
      y += gap;
    }

    final drawing = recorder.endRecording();
    try {
      final height = y + padding;
      final scale = math.min(1.6, 12000 / height);
      if (scale < 0.5) {
        throw const FormatException(
          'A crônica é longa demais para uma única imagem legível. Use o PDF das crônicas.',
        );
      }
      final output = ui.PictureRecorder();
      final target = ui.Canvas(output)..scale(scale);
      target.drawRect(
        Rect.fromLTWH(0, 0, width, height),
        ui.Paint()..color = paper.surface,
      );
      target.drawPicture(drawing);
      final picture = output.endRecording();
      try {
        final image = await picture.toImage(
          (width * scale).ceil(),
          (height * scale).ceil(),
        );
        try {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          if (png == null) {
            throw const FormatException('Não foi possível gerar a imagem.');
          }
          return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
        } finally {
          image.dispose();
        }
      } finally {
        picture.dispose();
      }
    } finally {
      drawing.dispose();
    }
  } finally {
    if (recorder.isRecording) recorder.endRecording().dispose();
    for (final painter in painters) {
      painter.dispose();
    }
    for (final image in illustrations) {
      image.dispose();
    }
  }
}

Rect _imageBounds(Rect frame, PictureLayout layout) {
  final scale = layout.size * layout.zoom;
  final alignment = scale <= 1
      ? Alignment(layout.x, layout.y)
      : Alignment(-layout.x, -layout.y);
  return alignment.inscribe(
    Size(frame.width * scale, frame.height * scale),
    frame,
  );
}

void _paintImage(
  ui.Canvas canvas,
  ui.Image image,
  Rect frame,
  PictureLayout layout,
) {
  final alignment = Alignment(layout.x, layout.y);
  final size = Size(image.width.toDouble(), image.height.toDouble());
  final bounds = _imageBounds(frame, layout);
  final fit = applyBoxFit(BoxFit.contain, size, bounds.size);
  canvas.save();
  canvas.clipRect(frame);
  canvas.drawImageRect(
    image,
    Offset.zero & size,
    alignment.inscribe(fit.destination, bounds),
    ui.Paint()..filterQuality = ui.FilterQuality.medium,
  );
  canvas.restore();
}
