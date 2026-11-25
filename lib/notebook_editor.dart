import 'package:material_ui/material_ui.dart';

import 'campaigns.dart';

class NotebookEditor extends StatefulWidget {
  const NotebookEditor({
    super.key,
    required this.repository,
    required this.campaignId,
    required this.notebook,
    required this.isSession,
    required this.onClose,
    required this.onSaved,
    this.record,
  });

  final CampaignRepository repository;
  final String campaignId;
  final Notebook notebook;
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

  late final _id = widget.record?.id ?? newNotebookRecordId();
  late var _baseRecord = widget.record;
  late final _original =
      widget.record?.text ??
      (title: '', body: '', answer: '', confidence: 'Não se aplica');
  late final _title = TextEditingController(text: _original.title);
  late final _body = TextEditingController(text: _original.body);
  late final _answer = TextEditingController(text: _original.answer);
  late String _confidence = _original.confidence;
  late String _category =
      widget.record?.category ??
      (widget.isSession ? 'Sessão' : _categories.first);
  bool _saving = false;
  bool _confirmingClose = false;
  String? _error;
  CampaignRecord? _current;

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

  Future<void> _close() async {
    if (_saving || _confirmingClose) return;
    if (_draft == _original) {
      widget.onClose();
      return;
    }
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
    if (discard == true) widget.onClose();
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
    setState(() {
      _saving = true;
      _error = null;
      _current = null;
    });
    try {
      await widget.repository.saveNotebookRecord(
        campaignId: widget.campaignId,
        notebook: widget.notebook,
        id: _id,
        category: _category,
        text: draft,
        original: _baseRecord,
      );
      if (mounted) widget.onSaved();
    } on NotebookConflict catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _current = error.current;
        });
      }
    } on Exception {
      if (mounted) {
        setState(
          () =>
              _error = 'Não foi possível salvar. Seu rascunho continua aberto.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _compareWithSaved(CampaignRecord current) {
    final previous = _baseRecord!.text;
    final draft = _draft;
    final remote = current.text;
    if (draft.title == previous.title) _title.text = remote.title;
    if (draft.body == previous.body) _body.text = remote.body;
    if (draft.answer == previous.answer) _answer.text = remote.answer;
    setState(() {
      if (draft.confidence == previous.confidence) {
        _confidence = remote.confidence;
      }
      _baseRecord = current;
      _current = null;
      _error = null;
    });
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
            widget.record == null
                ? (widget.isSession ? 'Nova crônica' : 'Novo registro')
                : (widget.isSession ? 'Editar crônica' : 'Editar registro'),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.record == null && !widget.isSession)
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: [
                  for (final category in _categories)
                    DropdownMenuItem(value: category, child: Text(category)),
                ],
                onChanged: _saving ? null : (value) => _category = value!,
              ),
            TextField(
              controller: _title,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            TextField(
              controller: _body,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Texto'),
              minLines: 5,
              maxLines: 16,
            ),
            TextField(
              controller: _answer,
              enabled: !_saving,
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
              onChanged: _saving ? null : (value) => _confidence = value!,
            ),
            const SizedBox(height: 16),
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
