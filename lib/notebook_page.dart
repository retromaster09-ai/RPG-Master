import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import 'campaigns.dart';
import 'mission_fields.dart';
import 'session_dates.dart';

class NotebookCoverImage extends StatefulWidget {
  const NotebookCoverImage({
    super.key,
    required this.repository,
    required this.campaignId,
    required this.hash,
    required this.height,
    this.fit = BoxFit.cover,
  });

  final CampaignRepository repository;
  final String campaignId;
  final String hash;
  final double height;
  final BoxFit fit;

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
        return SizedBox(
          height: widget.height,
          child: const Center(child: Icon(Icons.image_outlined)),
        );
      }
      return Image.memory(
        bytes,
        width: double.infinity,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, _, _) => SizedBox(
          height: widget.height,
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        ),
      );
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
  });

  final CampaignRecord record;
  final CampaignRepository repository;
  final String campaignId;
  final VoidCallback onBack;
  final VoidCallback? onEdit;

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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: NotebookCoverImage(
                    repository: repository,
                    campaignId: campaignId,
                    hash: hash,
                    height: 248,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            SelectableText(record.title, style: theme.textTheme.headlineMedium),
            if (record.dates.isNotEmpty)
              Text(record.dates.map(sessionDateLabel).join(' · ')),
            if (record.confidence case final confidence?)
              Text('Confiança · $confidence'),
            if (record.body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SelectableText(
                  record.body,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            if (record.answer.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('Resposta', style: theme.textTheme.titleMedium),
              SelectableText(record.answer, style: theme.textTheme.bodyLarge),
            ],
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
