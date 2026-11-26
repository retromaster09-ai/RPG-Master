import 'package:material_ui/material_ui.dart';

import 'hypotheses.dart';

class InvestigationConclusionDialog extends StatefulWidget {
  const InvestigationConclusionDialog({
    super.key,
    required this.initialReason,
    required this.hypothesis,
  });

  final String initialReason;
  final bool hypothesis;

  @override
  State<InvestigationConclusionDialog> createState() =>
      _InvestigationConclusionDialogState();
}

class _InvestigationConclusionDialogState
    extends State<InvestigationConclusionDialog> {
  late final _reason = TextEditingController(text: widget.initialReason);
  HypothesisStatus? _status;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.hypothesis ? 'Concluir hipótese' : 'Concluir registro'),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<HypothesisStatus>(
          decoration: const InputDecoration(labelText: 'Conclusão da mesa'),
          items: [
            for (final status in [
              HypothesisStatus.confirmed,
              HypothesisStatus.refuted,
            ])
              DropdownMenuItem(
                value: status,
                child: Text(
                  status.conclusionLabel(hypothesis: widget.hypothesis),
                ),
              ),
          ],
          onChanged: (status) => setState(() => _status = status),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _reason,
          decoration: const InputDecoration(
            labelText: 'Como a mesa chegou à conclusão?',
          ),
          maxLength: 2000,
          minLines: 2,
          maxLines: 5,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _status == null
            ? null
            : () => Navigator.pop(
                context,
                HypothesisResolution(
                  status: _status!,
                  reason: _reason.text.trim(),
                ),
              ),
        child: const Text('Concluir'),
      ),
    ],
  );
}

class InvestigationConclusion extends StatelessWidget {
  const InvestigationConclusion({
    super.key,
    required this.resolution,
    required this.hypothesis,
    this.compact = false,
  });

  final HypothesisResolution resolution;
  final bool compact;
  final bool hypothesis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          resolution.status.conclusionLabel(hypothesis: hypothesis),
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        if (resolution.reason.isNotEmpty)
          if (compact)
            Text(
              resolution.reason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          else
            SelectableText(resolution.reason),
      ],
    );
  }
}
