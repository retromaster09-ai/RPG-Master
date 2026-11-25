import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import 'campaigns.dart';

class GmNotePage extends StatefulWidget {
  const GmNotePage({
    super.key,
    required this.repository,
    required this.campaign,
    required this.note,
    required this.onBack,
    required this.onEdit,
  });

  final CampaignRepository repository;
  final Campaign campaign;
  final GmNote note;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  @override
  State<GmNotePage> createState() => _GmNotePageState();
}

class _GmNotePageState extends State<GmNotePage> {
  late final Future<Uint8List>? _cover = switch (widget.note.text.coverHash) {
    final hash? => widget.repository.readGmCover(widget.campaign, hash),
    null => null,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = widget.note.text;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) widget.onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: widget.onBack),
          title: Text(widget.campaign.name),
          actions: [
            IconButton(
              onPressed: widget.onEdit,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar página',
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  text.kind == GmNoteKind.note
                      ? text.section.label
                      : text.kind.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  text.title,
                  style: theme.textTheme.headlineMedium,
                ),
                if (_cover case final cover?) ...[
                  const SizedBox(height: 16),
                  FutureBuilder(
                    future: cover,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text('Não foi possível carregar a capa.');
                      }
                      final bytes = snapshot.data;
                      if (bytes == null) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: CircularProgressIndicator(),
                        );
                      }
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.memory(
                          bytes,
                          height: 260,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const Text('Não foi possível abrir a capa.'),
                        ),
                      );
                    },
                  ),
                ],
                if (text.body.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  SelectableText(text.body, style: theme.textTheme.bodyLarge),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
