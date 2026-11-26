import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import 'campaigns.dart';
import 'cover_frame.dart';
import 'hypothesis_fields.dart';
import 'notebook_format.dart';
import 'notebook_picture_editor.dart';
import 'notebook_rich_text.dart';
import 'mission_fields.dart';
import 'session_dates.dart';

class NotebookCoverImage extends StatefulWidget {
  const NotebookCoverImage({
    super.key,
    required this.repository,
    required this.campaignId,
    required this.hash,
    this.layout = const CampaignCoverLayout(fill: false),
    this.pictureLayout,
  });

  final CampaignRepository repository;
  final String campaignId;
  final String hash;
  final CampaignCoverLayout layout;
  final PictureLayout? pictureLayout;

  @override
  State<NotebookCoverImage> createState() => _NotebookCoverImageState();
}

class _NotebookCoverImageState extends State<NotebookCoverImage> {
  late Future<Uint8List> _image = _load();

  Future<Uint8List> _load() =>
      widget.repository.readNotebookCover(widget.campaignId, widget.hash);

  @override
  void didUpdateWidget(NotebookCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hash != widget.hash ||
        oldWidget.campaignId != widget.campaignId ||
        oldWidget.repository != widget.repository) {
      _image = _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _image,
    builder: (context, snapshot) {
      final bytes = snapshot.data;
      if (snapshot.connectionState != ConnectionState.done || bytes == null) {
        return const Center(child: Icon(Icons.image_outlined));
      }
      if (widget.pictureLayout case final layout?) {
        return NotebookPictureFrame(bytes: bytes, layout: layout);
      }
      return CoverFrame(bytes: bytes, layout: widget.layout);
    },
  );
}

class NotebookPage extends StatelessWidget {
  const NotebookPage({
    super.key,
    required this.record,
    required this.repository,
    required this.campaignId,
    required this.onBack,
    this.onEdit,
    this.onExport,
  });

  final CampaignRecord record;
  final CampaignRepository repository;
  final String campaignId;
  final VoidCallback onBack;
  final VoidCallback? onEdit;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: onBack),
          title: Text(record.category ?? 'Registro'),
          actions: [
            if (onExport != null)
              IconButton(
                onPressed: onExport,
                tooltip: 'Exportar crônica como imagem',
                icon: const Icon(Icons.image_outlined),
              ),
            if (onEdit != null)
              IconButton(
                onPressed: onEdit,
                tooltip: 'Editar',
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (record.coverHash case final hash?)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: SizedBox(
                  height: 248,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: NotebookCoverImage(
                      repository: repository,
                      campaignId: campaignId,
                      hash: hash,
                    ),
                  ),
                ),
              ),
            _ReadingSheet(
              record: record,
              theme: theme,
              repository: repository,
              campaignId: campaignId,
            ),
            if (record.category == 'Investigação' &&
                record.confidence == 'Hipótese' &&
                record.resolution.closed)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: HypothesisConclusion(resolution: record.resolution),
              ),
            if (record.mission case final plan?) ...[
              const SizedBox(height: 18),
              MissionSummary(plan: plan),
              MissionChecklist(plan: plan),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReadingSheet extends StatelessWidget {
  const _ReadingSheet({
    required this.record,
    required this.theme,
    required this.repository,
    required this.campaignId,
  });

  final CampaignRecord record;
  final ThemeData theme;
  final CampaignRepository repository;
  final String campaignId;

  List<Widget> _body(TextStyle? style, bool lightPaper) {
    final presentation = record.presentation;
    final text = record.body;
    if (presentation.pictures.isEmpty) {
      return [
        if (text.isNotEmpty)
          SelectableText.rich(
            notebookTextSpan(
              text,
              presentation.bodyMarks,
              style,
              lightPaper: lightPaper,
            ),
          ),
      ];
    }
    final paragraphs = notebookParagraphs(text);
    final pictures = <int, List<NotebookPicture>>{};
    for (final picture in presentation.pictures) {
      final position = picture.afterParagraph.clamp(-1, paragraphs.length - 1);
      pictures.putIfAbsent(position, () => []).add(picture);
    }
    return [
      for (final picture in pictures[-1] ?? const <NotebookPicture>[])
        _illustration(picture, style),
      for (final (index, range) in paragraphs.indexed) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SelectableText.rich(
            notebookTextSpan(
              text.substring(range.start, range.end),
              sliceNotebookMarks(
                presentation.bodyMarks,
                range.start,
                range.end,
              ),
              style,
              lightPaper: lightPaper,
            ),
          ),
        ),
        for (final picture in pictures[index] ?? const <NotebookPicture>[])
          _illustration(picture, style),
      ],
    ];
  }

  Widget _illustration(NotebookPicture picture, TextStyle? style) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (picture.displayedHash case final hash?)
          SizedBox(
            height: notebookPictureHeight,
            child: NotebookCoverImage(
              repository: repository,
              campaignId: campaignId,
              hash: hash,
              pictureLayout: picture.layout,
            ),
          ),
        if (picture.caption.isNotEmpty)
          Text(
            picture.caption,
            textAlign: TextAlign.center,
            style: style?.copyWith(fontStyle: FontStyle.italic),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final presentation = record.presentation;
    final (
      background,
      edge,
      ink,
      font,
      lightPaper,
    ) = switch (presentation.paper) {
      NotebookPaper.plain => (
        null,
        null,
        theme.colorScheme.onSurface,
        null,
        false,
      ),
      NotebookPaper.parchment => (
        const Color(0xfff4dfae),
        const Color(0xffe0bb83),
        const Color(0xff3f2818),
        'RpgScript',
        true,
      ),
      NotebookPaper.diary => (
        const Color(0xffead0a7),
        const Color(0xffc19771),
        const Color(0xff48261e),
        'Crimson Text',
        true,
      ),
      NotebookPaper.future => (
        const Color(0xff142736),
        const Color(0xff101d2a),
        const Color(0xffceeeff),
        'RpgMono',
        false,
      ),
    };
    final bodyStyle = theme.textTheme.bodyLarge?.copyWith(
      fontFamily: font,
      color: ink,
      fontSize: presentation.paper == NotebookPaper.parchment ? 19 : null,
      height: 1.55,
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectableText(
          record.title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontFamily: font,
            color: ink,
          ),
        ),
        if (record.dates.isNotEmpty)
          Text(
            record.dates.map(sessionDateLabel).join(' · '),
            style: bodyStyle,
          ),
        if (record.confidence case final confidence?
            when confidence != 'Hipótese' ||
                record.category != 'Investigação' ||
                !record.resolution.closed)
          Text('Confiança · $confidence', style: bodyStyle),
        if (record.body.isNotEmpty || presentation.pictures.isNotEmpty) ...[
          const SizedBox(height: 16),
          ..._body(bodyStyle, lightPaper),
        ],
        if (record.answer.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Resposta',
            style: bodyStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
          SelectableText.rich(
            notebookTextSpan(
              record.answer,
              presentation.answerMarks,
              bodyStyle,
              lightPaper: lightPaper,
            ),
          ),
        ],
      ],
    );
    if (background == null || edge == null) return content;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: edge),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [background, edge, background],
          stops: const [0, 0.86, 1],
        ),
      ),
      child: content,
    );
  }
}
