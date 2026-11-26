import 'package:material_ui/material_ui.dart';

import 'hypotheses.dart';

class HypothesisConclusionDialog extends StatefulWidget {
  const HypothesisConclusionDialog({super.key, required this.initialReason});

  final String initialReason;

  @override
  State<HypothesisConclusionDialog> createState() =>
      _HypothesisConclusionDialogState();
}

class _HypothesisConclusionDialogState
    extends State<HypothesisConclusionDialog> {
  late final _reason = TextEditingController(text: widget.initialReason);
  HypothesisStatus? _status;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Concluir hipótese'),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<HypothesisStatus>(
          decoration: const InputDecoration(labelText: 'Conclusão da mesa'),
          items: const [
            DropdownMenuItem(
              value: HypothesisStatus.confirmed,
              child: Text('Confirmada'),
            ),
            DropdownMenuItem(
              value: HypothesisStatus.refuted,
              child: Text('Refutada'),
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

class HypothesisConclusion extends StatelessWidget {
  const HypothesisConclusion({
    super.key,
    required this.resolution,
    this.compact = false,
  });

  final HypothesisResolution resolution;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          resolution.status.label,
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
