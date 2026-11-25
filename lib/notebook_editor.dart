import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

import 'campaigns.dart';
import 'notebook_sync.dart';
import 'session_dates.dart';

class NotebookEditor extends StatefulWidget {
  const NotebookEditor({
    super.key,
    required this.sync,
    required this.epoch,
    required this.isSession,
    required this.onClose,
    required this.onSaved,
    this.record,
    this.savedDraft,
  });

  final NotebookSync sync;
  final int epoch;
  final NotebookDraft? savedDraft;
  final CampaignRecord? record;
  final bool isSession;
  final VoidCallback onClose;
  final VoidCallback onSaved;

  @override
  State<NotebookEditor> createState() => _NotebookEditorState();
}

class _NotebookEditorState extends State<NotebookEditor> {
  static const _categories = [
    'Investigação',
    'Personagem',
    'Lugar',
    'Objeto',
    'Missão',
    'Carta',
  ];
  static const _confidenceOptions = [
    'Não se aplica',
    'Hipótese',
    'Em avaliação',
    'Baixa',
    'Média',
    'Alta',
  ];

  late final _id =
      widget.savedDraft?.id ?? widget.record?.id ?? newNotebookRecordId();
  late var _baseRecord = widget.savedDraft?.original ?? widget.record;
  late final _original =
      _baseRecord?.text ??
      (title: '', body: '', answer: '', confidence: 'Não se aplica');
  late final _initial = widget.savedDraft?.text ?? _original;
  late final _title = TextEditingController(text: _initial.title);
  late final _body = TextEditingController(text: _initial.body);
  late final _answer = TextEditingController(text: _initial.answer);
  late String _confidence = _initial.confidence;
  late final String _startingCategory =
      _baseRecord?.category ??
      (widget.isSession ? 'Sessão' : _categories.first);
  late String _category = widget.savedDraft?.category ?? _startingCategory;
  late List<String> _dates =
      widget.savedDraft?.dates ?? _baseRecord?.dates ?? const [];
  bool _saving = false;
  bool _choosingDate = false;
  bool _confirmingClose = false;
  bool _savedLocally = false;
  late String? _error = widget.savedDraft?.message;
  late CampaignRecord? _current = widget.savedDraft?.remote;

  NotebookText get _draft => (
    title: _title.text,
    body: _body.text,
    answer: _answer.text,
    confidence: _confidence,
  );

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _answer.dispose();
    super.dispose();
  }

  NotebookDraft _change(DraftStatus status) => NotebookDraft(
    id: _id,
    category: _category,
    epoch: widget.savedDraft?.epoch ?? widget.epoch,
    text: _draft,
    dates: widget.isSession ? _dates : null,
    original: _baseRecord,
    status: status,
    message: status == DraftStatus.editing ? _error : null,
    remote: status == DraftStatus.editing ? _current : null,
  );

  Future<void> _persistDraft() async {
    try {
      await widget.sync.keep(_change(DraftStatus.editing));
      if (mounted && !_savedLocally) setState(() => _savedLocally = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _savedLocally = false;
          _error = 'Não foi possível guardar o rascunho neste aparelho.';
        });
      }
    }
  }

  Future<void> _close() async {
    if (_saving || _confirmingClose) return;
    if (widget.savedDraft == null &&
        !_savedLocally &&
        _draft == _original &&
        listEquals(_dates, _baseRecord?.dates ?? const []) &&
        _category == _startingCategory) {
      widget.onClose();
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.sync.keep(_change(DraftStatus.editing));
      if (mounted) widget.onClose();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível guardar o rascunho neste aparelho.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseDate([int? index]) async {
    if (_choosingDate || _saving) return;
    _choosingDate = true;
    final previous = index == null ? null : _dates[index];
    try {
      final date = await showDatePicker(
        context: context,
        initialDate: previous == null ? DateTime.now() : sessionDay(previous),
        firstDate: DateTime(1),
        lastDate: DateTime(9999, 12, 31),
        helpText: 'Data da sessão',
        cancelText: 'Cancelar',
        confirmText: 'Confirmar',
      );
      if (!mounted || date == null) return;
      final value = sessionDateValue(date);
      if (previous != null && sessionDay(previous) == date) return;
      if (_dates.any((saved) => sessionDay(saved) == date)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Essa data já está na crônica.')),
        );
        return;
      }
      final dates = [..._dates];
      if (index == null) {
        dates.add(value);
      } else {
        dates[index] = value;
      }
      _updateDates(dates..sort());
    } finally {
      _choosingDate = false;
    }
  }

  void _updateDates(List<String> dates) {
    setState(() => _dates = dates);
    unawaited(_persistDraft());
  }

  Future<void> _discard() async {
    if (_saving || _confirmingClose) return;
    _confirmingClose = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar rascunho?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _confirmingClose = false;
    if (discard != true) return;
    setState(() => _saving = true);
    try {
      await widget.sync.discard(_id);
      if (mounted) widget.onClose();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível descartar o rascunho.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final draft = _draft;
    if ([
      draft.title,
      draft.body,
      draft.answer,
    ].every((value) => value.trim().isEmpty)) {
      setState(() => _error = 'Escreva um título, um texto ou uma resposta.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.sync.keep(_change(DraftStatus.queued));
      if (mounted) widget.onSaved();
      unawaited(widget.sync.refresh());
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível salvar neste aparelho. Seu texto continua aberto.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _compareWithSaved(CampaignRecord current) {
    final previousRecord = _baseRecord!;
    final previous = previousRecord.text;
    final draft = _draft;
    final remote = current.text;
    if (draft.title == previous.title) _title.text = remote.title;
    if (draft.body == previous.body) _body.text = remote.body;
    if (draft.answer == previous.answer) _answer.text = remote.answer;
    setState(() {
      if (draft.confidence == previous.confidence) {
        _confidence = remote.confidence;
      }
      if (listEquals(_dates, previousRecord.dates)) _dates = current.dates;
      _baseRecord = current;
      _current = null;
      _error = null;
    });
    unawaited(_persistDraft());
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _close),
          title: Text(
            _baseRecord == null
                ? (widget.isSession ? 'Nova crônica' : 'Novo registro')
                : (widget.isSession ? 'Editar crônica' : 'Editar registro'),
          ),
          actions: [
            IconButton(
              onPressed: _saving ? null : _discard,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Descartar rascunho',
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_baseRecord == null && !widget.isSession)
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: [
                  for (final category in _categories)
                    DropdownMenuItem(value: category, child: Text(category)),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        _category = value!;
                        unawaited(_persistDraft());
                      },
              ),
            TextField(
              controller: _title,
              enabled: !_saving,
              onChanged: (_) => unawaited(_persistDraft()),
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            if (widget.isSession) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final (index, date) in _dates.indexed)
                    InputChip(
                      label: Text(sessionDateLabel(date)),
                      onPressed: _saving ? null : () => _chooseDate(index),
                      onDeleted: _saving
                          ? null
                          : () => _updateDates([..._dates]..removeAt(index)),
                      deleteButtonTooltipMessage: 'Remover data',
                    ),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _chooseDate,
                    icon: const Icon(Icons.event_outlined),
                    label: const Text('Adicionar data'),
                  ),
                ],
              ),
            ],
            TextField(
              controller: _body,
              enabled: !_saving,
              onChanged: (_) => unawaited(_persistDraft()),
              decoration: const InputDecoration(labelText: 'Texto'),
              minLines: 5,
              maxLines: 16,
            ),
            TextField(
              controller: _answer,
              enabled: !_saving,
              onChanged: (_) => unawaited(_persistDraft()),
              decoration: const InputDecoration(labelText: 'Resposta'),
              minLines: 2,
              maxLines: 8,
            ),
            DropdownButtonFormField<String>(
              key: ValueKey(_baseRecord),
              initialValue: _confidence,
              decoration: const InputDecoration(labelText: 'Confiança'),
              items: [
                for (final value in {..._confidenceOptions, _confidence})
                  DropdownMenuItem(value: value, child: Text(value)),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      _confidence = value!;
                      unawaited(_persistDraft());
                    },
            ),
            const SizedBox(height: 16),
            if (_savedLocally && _error == null)
              const Text('Rascunho guardado neste aparelho.'),
            if (_error case final error?)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (current != null)
              ExpansionTile(
                title: const Text('Versão salva por outra pessoa'),
                children: [
                  ListTile(
                    title: const Text('Título'),
                    subtitle: SelectableText(current.title),
                  ),
                  ListTile(
                    title: const Text('Texto'),
                    subtitle: SelectableText(current.body),
                  ),
                  ListTile(
                    title: const Text('Resposta'),
                    subtitle: SelectableText(current.answer),
                  ),
                  ListTile(
                    title: const Text('Confiança'),
                    subtitle: Text(current.text.confidence),
                  ),
                  if (widget.isSession)
                    ListTile(
                      title: const Text('Datas da sessão'),
                      subtitle: Text(
                        current.dates.isEmpty
                            ? 'Sem data'
                            : current.dates.map(sessionDateLabel).join(' · '),
                      ),
                    ),
                  if (_baseRecord != null)
                    TextButton(
                      onPressed: () => _compareWithSaved(current),
                      child: const Text('Manter meu rascunho para revisar'),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Salvando…' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
