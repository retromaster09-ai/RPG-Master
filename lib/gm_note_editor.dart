import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'campaigns.dart';
import 'cover_picker.dart';
import 'cover_frame.dart';
import 'notebook_format.dart';
import 'notebook_page.dart';
import 'notebook_picture_editor.dart';
import 'notebook_rich_text.dart';

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
  late final _initialVisual =
      widget.note?.presentation ?? const NotebookPresentation();
  late final _body = NotebookTextController(
    _initial.body,
    _initialVisual.bodyMarks,
  );
  late var _paper = _initialVisual.paper;
  late var _coverLayout = _initialVisual.cover;
  late var _pictures = _initialVisual.pictures;
  late final _initialPreparation =
      widget.note?.preparation ?? emptyGmPreparation;
  late final _tags = TextEditingController(text: _initialPreparation.tags);
  late final _cue = TextEditingController(text: _initialPreparation.cue);
  late final _music = TextEditingController(text: _initialPreparation.music);
  late var _state = _initialPreparation.state;
  late var _nextSession = _initialPreparation.nextSession;

  NotebookPresentation get _visual => NotebookPresentation(
    paper: _paper,
    cover: _coverLayout,
    bodyMarks: _body.marks,
    pictures: _pictures,
  );

  GmPreparation get _preparation => (
    state: _state,
    tags: _tags.text,
    cue: _cue.text,
    music: _music.text,
    nextSession: _nextSession,
  );
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
    _tags.dispose();
    _cue.dispose();
    _music.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_saving || _pickingCover || _confirmingClose) return;
    if (_draft == _initial &&
        _newCover == null &&
        _visual.sameAs(_initialVisual) &&
        _preparation == _initialPreparation) {
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

  Future<void> _chooseImage({bool inline = false}) async {
    setState(() {
      _pickingCover = true;
      _error = null;
    });
    try {
      final png = await pickCoverImage(maxPngBytes: 1024 * 1024);
      if (png == null) return;
      if (!mounted) return;
      setState(() {
        if (inline) {
          _pictures = [
            ..._pictures,
            NotebookPicture(
              png: png,
              afterParagraph: notebookParagraphs(_body.text).length - 1,
            ),
          ];
        } else {
          _newCover = png;
        }
      });
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

  Future<void> _editPicture(int index) async {
    final edited = await showDialog<NotebookPicture>(
      context: context,
      barrierDismissible: false,
      builder: (context) => NotebookPictureEditor(
        picture: _pictures[index],
        paragraphCount: notebookParagraphs(_body.text).length,
        load: (hash) => widget.repository.readGmCover(widget.campaign, hash),
      ),
    );
    if (!mounted || edited == null) return;
    setState(() => _pictures = [..._pictures]..[index] = edited);
  }

  Future<String?> _upload(Uint8List? png, String? saved) async => png == null
      ? saved
      : await widget.repository.uploadGmCover(widget.campaign, png);

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
      final visual = _visual;
      final pictures = <NotebookPicture>[];
      for (final picture in visual.pictures) {
        pictures.add(
          picture.uploaded(
            original: await _upload(picture.png, picture.hash),
            cutout: await _upload(picture.cutoutPng, picture.cutoutHash),
          ),
        );
      }
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
        preparation: _preparation,
        presentation: NotebookPresentation(
          paper: visual.paper,
          cover: visual.cover,
          bodyMarks: visual.bodyMarks,
          pictures: pictures,
        ),
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

  Widget _preparationFields(bool busy) => ExpansionTile(
    title: const Text('Preparação da sessão'),
    children: [
      SwitchListTile(
        title: const Text('Usar na próxima sessão'),
        subtitle: const Text('Aparece no filtro Próxima sessão da aba Mestre.'),
        value: _nextSession,
        onChanged: busy
            ? null
            : (value) => setState(() => _nextSession = value),
      ),
      DropdownButtonFormField<String>(
        initialValue: _state,
        decoration: const InputDecoration(labelText: 'Estado'),
        items: [
          for (final entry in gmPreparationStates.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
        onChanged: busy ? null : (value) => setState(() => _state = value!),
      ),
      for (final (controller, label, hint, limit) in [
        (_tags, 'Etiquetas', 'Ex.: pista, castelo', 1000),
        (
          _cue,
          'Condições ou testes',
          'Ex.: revelar se encontrarem a carta',
          4000,
        ),
        (_music, 'Referência de música', 'Nome da faixa ou link', 2048),
      ])
        TextField(
          controller: controller,
          enabled: !busy,
          maxLength: limit,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            counterText: '',
          ),
        ),
    ],
  );

  Widget _pictureFields(bool busy) => ExpansionTile(
    title: const Text('Imagens no texto'),
    children: [
      for (final (index, picture) in _pictures.indexed)
        ListTile(
          leading: const Icon(Icons.image_outlined),
          title: Text(
            picture.caption.isEmpty ? 'Imagem ${index + 1}' : picture.caption,
          ),
          subtitle: Text(notebookPicturePosition(picture.afterParagraph)),
          onTap: busy ? null : () => _editPicture(index),
          trailing: IconButton(
            tooltip: 'Remover imagem',
            icon: const Icon(Icons.close),
            onPressed: busy
                ? null
                : () => setState(
                    () => _pictures = [..._pictures]..removeAt(index),
                  ),
          ),
        ),
      TextButton.icon(
        onPressed: busy || _pictures.length >= 12
            ? null
            : () => _chooseImage(inline: true),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Inserir imagem no texto'),
      ),
    ],
  );

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
          padding: EdgeInsets.symmetric(
            vertical: 16,
            horizontal: ((MediaQuery.sizeOf(context).width - 928) / 2).clamp(
              16.0,
              double.infinity,
            ),
          ),
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
            if (_newCover != null || _coverHash != null) ...[
              SizedBox(
                height: 160,
                child: _newCover != null
                    ? CoverFrame(bytes: _newCover!, layout: _coverLayout)
                    : NotebookCoverImage.private(
                        repository: widget.repository,
                        campaign: widget.campaign,
                        hash: _coverHash!,
                        layout: _coverLayout,
                      ),
              ),
              NotebookCoverControls(
                layout: _coverLayout,
                onChangeEnd: () {},
                onChanged: busy
                    ? null
                    : (value) => setState(() => _coverLayout = value),
              ),
            ],
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : _chooseImage,
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
            DropdownButtonFormField<NotebookPaper>(
              initialValue: _paper,
              decoration: const InputDecoration(labelText: 'Estilo de página'),
              items: [
                for (final paper in NotebookPaper.values)
                  DropdownMenuItem(value: paper, child: Text(paper.label)),
              ],
              onChanged: busy
                  ? null
                  : (value) => setState(() => _paper = value!),
            ),
            NotebookFormattingBar(
              controller: _body,
              enabled: !busy,
              onChanged: () => setState(() {}),
            ),
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
            _pictureFields(busy),
            _preparationFields(busy),
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
