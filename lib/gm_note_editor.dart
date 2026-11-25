import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'campaigns.dart';

class GmNoteEditor extends StatefulWidget {
  const GmNoteEditor({
    super.key,
    required this.repository,
    required this.campaign,
    required this.onClose,
    required this.onSaved,
    this.note,
  });

  final CampaignRepository repository;
  final Campaign campaign;
  final VoidCallback onClose;
  final VoidCallback onSaved;
  final GmNote? note;

  @override
  State<GmNoteEditor> createState() => _GmNoteEditorState();
}

class _GmNoteEditorState extends State<GmNoteEditor> {
  late final _id = widget.note?.id ?? newNotebookRecordId();
  late final _initial =
      widget.note?.text ?? (title: '', body: '', section: GmSection.idea);
  late final _title = TextEditingController(text: _initial.title);
  late final _body = TextEditingController(text: _initial.body);
  late var _section = _initial.section;
  bool _saving = false;
  bool _confirmingClose = false;
  String? _error;

  GmNoteText get _draft =>
      (title: _title.text, body: _body.text, section: _section);

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_saving || _confirmingClose) return;
    if (_draft == _initial) {
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
    if (draft.title.trim().isEmpty) {
      setState(() => _error = 'Escreva um título para a nota.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.saveGmNote(
        campaign: widget.campaign,
        id: _id,
        draft: draft,
        original: widget.note,
      );
      if (mounted) widget.onSaved();
    } on GmNoteConflict {
      if (!mounted) return;
      setState(() {
        _error =
            'A nota mudou no servidor. Copie seu texto antes de voltar '
            'à lista para conferir a versão mais recente.';
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = switch (error.code) {
          '42501' => 'O roteiro está reservado ao criador da campanha.',
          _ => 'Não foi possível salvar. Seu rascunho continua aberto.',
        };
      });
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _close),
          title: Text(
            widget.note == null ? 'Nova nota privada' : 'Editar nota',
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _title,
              enabled: !_saving,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            DropdownButtonFormField<GmSection>(
              initialValue: _section,
              decoration: const InputDecoration(labelText: 'Seção'),
              items: [
                for (final section in GmSection.values)
                  DropdownMenuItem(value: section, child: Text(section.label)),
              ],
              onChanged: _saving
                  ? null
                  : (section) => setState(() => _section = section!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _body,
              enabled: !_saving,
              keyboardType: TextInputType.multiline,
              minLines: 8,
              maxLines: null,
              maxLength: 100000,
              decoration: const InputDecoration(
                labelText: 'Texto do roteiro',
                alignLabelWithHint: true,
                counterText: '',
              ),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Salvando…' : 'Salvar nota privada'),
            ),
          ],
        ),
      ),
    );
  }
}
