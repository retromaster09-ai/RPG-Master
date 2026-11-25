import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
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
      widget.note?.text ??
      (
        title: '',
        body: '',
        section: GmSection.idea,
        kind: GmNoteKind.note,
        coverHash: null,
      );
  late final _title = TextEditingController(text: _initial.title);
  late final _body = TextEditingController(text: _initial.body);
  late var _section = _initial.section;
  late var _kind = _initial.kind;
  late String? _coverHash = _initial.coverHash;
  Uint8List? _newCover;
  bool _pickingCover = false;
  bool _saving = false;
  bool _confirmingClose = false;
  String? _error;

  GmNoteText get _draft => (
    title: _title.text,
    body: _body.text,
    section: _section,
    kind: _kind,
    coverHash: _coverHash,
  );

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_saving || _pickingCover || _confirmingClose) return;
    if (_draft == _initial && _newCover == null) {
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

  Future<void> _chooseCover() async {
    setState(() {
      _pickingCover = true;
      _error = null;
    });
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Imagens PNG ou JPEG',
            extensions: ['png', 'jpg', 'jpeg'],
            mimeTypes: ['image/png', 'image/jpeg'],
            uniformTypeIdentifiers: ['public.png', 'public.jpeg'],
          ),
        ],
      );
      if (file == null) return;
      if (await file.length() > 25 * 1024 * 1024) {
        throw const FormatException(
          'Imagem grande demais. Escolha um arquivo de até 25 MB.',
        );
      }
      final png = await _coverPng(await file.readAsBytes());
      if (mounted) setState(() => _newCover = png);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível abrir a imagem. Escolha um PNG ou JPEG.',
        );
      }
    } finally {
      if (mounted) setState(() => _pickingCover = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _pickingCover) return;
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
      final newCover = _newCover;
      final coverHash = newCover == null
          ? draft.coverHash
          : await widget.repository.uploadGmCover(widget.campaign, newCover);
      await widget.repository.saveGmNote(
        campaign: widget.campaign,
        id: _id,
        draft: (
          title: draft.title,
          body: draft.body,
          section: draft.section,
          kind: draft.kind,
          coverHash: coverHash,
        ),
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
    final busy = _saving || _pickingCover;
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
            DropdownButtonFormField<GmNoteKind>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                for (final kind in GmNoteKind.values)
                  DropdownMenuItem(value: kind, child: Text(kind.label)),
              ],
              onChanged: busy ? null : (kind) => setState(() => _kind = kind!),
            ),
            if (_kind == GmNoteKind.note)
              DropdownButtonFormField<GmSection>(
                initialValue: _section,
                decoration: const InputDecoration(labelText: 'Seção'),
                items: [
                  for (final section in GmSection.values)
                    DropdownMenuItem(
                      value: section,
                      child: Text(section.label),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (section) => setState(() => _section = section!),
              ),
            const SizedBox(height: 12),
            if (_newCover case final cover?)
              Image.memory(cover, height: 160, fit: BoxFit.contain),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : _chooseCover,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    _coverHash != null || _newCover != null
                        ? 'Trocar capa'
                        : 'Adicionar capa',
                  ),
                ),
                if (_coverHash != null || _newCover != null)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            _newCover = null;
                            _coverHash = null;
                          }),
                    child: const Text('Remover capa'),
                  ),
              ],
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
              onPressed: busy ? null : _save,
              child: Text(_saving ? 'Salvando…' : 'Salvar nota privada'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<Uint8List> _coverPng(Uint8List input) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(input);
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (width, height) {
      final largest = max(width, height);
      if (largest <= 1400) return const ui.TargetImageSize();
      return ui.TargetImageSize(
        width: max(1, (width * 1400 / largest).round()),
        height: max(1, (height * 1400 / largest).round()),
      );
    },
  );
  try {
    final frame = await codec.getNextFrame();
    try {
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw const FormatException('Não foi possível converter a capa.');
      }
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}
