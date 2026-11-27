import 'package:material_ui/material_ui.dart';

import 'campaigns.dart';
import 'notebook_page.dart';

class GmNotePage extends StatefulWidget {
  const GmNotePage({
    super.key,
    required this.repository,
    required this.campaign,
    required this.note,
    required this.onBack,
    required this.onEdit,
    required this.onTrash,
  });

  final CampaignRepository repository;
  final Campaign campaign;
  final GmNote note;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onTrash;

  @override
  State<GmNotePage> createState() => _GmNotePageState();
}

class _GmNotePageState extends State<GmNotePage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = widget.note.text;
    final prep = widget.note.preparation;
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
            IconButton(
              onPressed: widget.onTrash,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Mover para a lixeira',
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
                if (text.coverHash case final hash?) ...[
                  SizedBox(
                    height: 260,
                    child: NotebookCoverImage.private(
                      repository: widget.repository,
                      campaign: widget.campaign,
                      hash: hash,
                      layout: widget.note.presentation.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                NotebookReadingSheet(
                  record: CampaignRecord(
                    text.title,
                    text.body,
                    presentation: widget.note.presentation,
                  ),
                  theme: theme,
                  repository: widget.repository,
                  campaignId: widget.campaign.id,
                  privateCampaign: widget.campaign,
                ),
                if (prep != emptyGmPreparation)
                  ExpansionTile(
                    title: const Text('Preparação da sessão'),
                    children: [
                      if (prep.nextSession)
                        const ListTile(title: Text('Na próxima sessão')),
                      if (prep.state != 'idea')
                        ListTile(
                          title: const Text('Estado'),
                          subtitle: Text(
                            gmPreparationStates[prep.state] ?? prep.state,
                          ),
                        ),
                      for (final (label, value) in [
                        ('Etiquetas', prep.tags),
                        ('Condições ou testes', prep.cue),
                        ('Referência de música', prep.music),
                      ])
                        if (value.trim().isNotEmpty)
                          ListTile(
                            title: Text(label),
                            subtitle: SelectableText(value),
                          ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
