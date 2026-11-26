import 'package:material_ui/material_ui.dart';

import 'campaigns.dart' show newNotebookRecordId;
import 'missions.dart';

class MissionSummary extends StatelessWidget {
  const MissionSummary({super.key, required this.plan});

  final MissionPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = plan.completedSteps;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${plan.status.label} · Prioridade ${plan.priority.toLowerCase()}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          if (plan.steps.isNotEmpty) ...[
            const SizedBox(height: 5),
            LinearProgressIndicator(
              value: done / plan.steps.length,
              semanticsLabel: 'Progresso da missão',
            ),
            const SizedBox(height: 4),
            Text('$done de ${plan.steps.length} etapas concluídas'),
          ],
        ],
      ),
    );
  }
}

class MissionFields extends StatelessWidget {
  const MissionFields({super.key, required this.plan, required this.onChanged});

  final MissionPlan plan;
  final ValueChanged<MissionPlan>? onChanged;

  Future<void> _step(BuildContext context, [int? index]) async {
    final result = await showDialog<_StepChange>(
      context: context,
      builder: (_) =>
          _StepDialog(step: index == null ? null : plan.steps[index]),
    );
    if (result == null || !context.mounted) return;
    final step = result.step;
    final updated = [...plan.steps];
    if (index == null) {
      if (step == null) return;
      updated.add(step);
    } else if (step == null) {
      updated.removeAt(index);
    } else {
      updated[index] = step;
    }
    onChanged?.call(plan.copyWith(steps: updated));
  }

  void _toggleStep(int index, bool value) {
    final steps = [...plan.steps];
    steps[index] = steps[index].copyWith(completed: value);
    final started = value && plan.status == MissionStatus.open
        ? MissionStatus.inProgress
        : null;
    onChanged?.call(plan.copyWith(steps: steps, status: started));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        DropdownButtonFormField<MissionStatus>(
          key: ValueKey(plan.status),
          initialValue: plan.status,
          decoration: const InputDecoration(labelText: 'Estado da missão'),
          items: [
            for (final state in MissionStatus.values)
              DropdownMenuItem(value: state, child: Text(state.label)),
          ],
          onChanged: onChanged == null
              ? null
              : (state) => onChanged!(plan.copyWith(status: state)),
        ),
        DropdownButtonFormField<String>(
          key: ValueKey(plan.priority),
          initialValue: plan.priority,
          decoration: const InputDecoration(labelText: 'Prioridade'),
          items: [
            for (final priority in {'Baixa', 'Normal', 'Alta', plan.priority})
              DropdownMenuItem(value: priority, child: Text(priority)),
          ],
          onChanged: onChanged == null
              ? null
              : (priority) => onChanged!(plan.copyWith(priority: priority)),
        ),
        const SizedBox(height: 12),
        for (final (index, step) in plan.steps.indexed)
          Card(
            child: Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(step.title),
                    subtitle: step.details.isEmpty ? null : Text(step.details),
                    value: step.completed,
                    onChanged: onChanged == null
                        ? null
                        : (value) => _toggleStep(index, value ?? false),
                  ),
                ),
                IconButton(
                  onPressed: onChanged == null
                      ? null
                      : () => _step(context, index),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar etapa',
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onChanged == null ? null : () => _step(context),
            icon: const Icon(Icons.playlist_add),
            label: const Text('Adicionar etapa'),
          ),
        ),
        if (plan.steps.isNotEmpty &&
            plan.completedSteps == plan.steps.length &&
            plan.status != MissionStatus.completed)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onChanged == null
                  ? null
                  : () => onChanged!(
                      plan.copyWith(status: MissionStatus.completed),
                    ),
              child: const Text('Concluir missão'),
            ),
          ),
      ],
    );
  }
}

typedef _StepChange = ({MissionStep? step});

class _StepDialog extends StatefulWidget {
  const _StepDialog({this.step});

  final MissionStep? step;

  @override
  State<_StepDialog> createState() => _StepDialogState();
}

class _StepDialogState extends State<_StepDialog> {
  late final _title = TextEditingController(text: widget.step?.title);
  late final _details = TextEditingController(text: widget.step?.details);
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final step =
        widget.step?.copyWith(
          title: _title.text.trim(),
          details: _details.text,
        ) ??
        MissionStep.fromJson({
          'id': newNotebookRecordId(),
          'title': _title.text.trim(),
          'details': _details.text,
          'completed': false,
        });
    Navigator.pop<_StepChange>(context, (step: step));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.step == null ? 'Nova etapa' : 'Editar etapa'),
    scrollable: true,
    content: Form(
      key: _form,
      child: Column(
        children: [
          TextFormField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nome da etapa'),
            validator: (value) =>
                value?.trim().isNotEmpty == true ? null : 'Dê um nome à etapa.',
          ),
          TextFormField(
            controller: _details,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Detalhes ou resultado',
            ),
          ),
        ],
      ),
    ),
    actions: [
      if (widget.step != null)
        TextButton(
          onPressed: () => Navigator.pop<_StepChange>(context, (step: null)),
          child: const Text('Remover etapa'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _save, child: const Text('Salvar etapa')),
    ],
  );
}
