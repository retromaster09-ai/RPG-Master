import 'dart:async';

import 'package:flutter/foundation.dart' show Uint8List, listEquals;
import 'package:material_ui/material_ui.dart';

import 'campaigns.dart';
import 'cover_picker.dart';
import 'cover_frame.dart';
import 'mission_fields.dart';
import 'missions.dart';
import 'notebook_sync.dart';
import 'notebook_page.dart';
import 'notebook_format.dart';
import 'notebook_picture_editor.dart';
import 'notebook_rich_text.dart';
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
    this.initialCategory,
    this.initialConfidence,
  });

  final NotebookSync sync;
  final int epoch;
  final NotebookDraft? savedDraft;
  final CampaignRecord? record;
  final bool isSession;
  final String? initialCategory;
  final String? initialConfidence;
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
      (
        title: '',
        body: '',
        answer: '',
        confidence: widget.initialConfidence ?? 'Não se aplica',
      );
  late final _initial = widget.savedDraft?.text ?? _original;
  late final _title = TextEditingController(text: _initial.title);
  late final _initialPresentation =
      widget.savedDraft?.presentation ??
      _baseRecord?.presentation ??
      const NotebookPresentation();
  late final _body = NotebookTextController(
    _initial.body,
    _initialPresentation.bodyMarks,
  );
  late final _answer = NotebookTextController(
    _initial.answer,
    _initialPresentation.answerMarks,
  );
  late NotebookPaper _paper = _initialPresentation.paper;
  late CampaignCoverLayout _coverLayout = _initialPresentation.cover;
  late List<NotebookPicture> _pictures = _initialPresentation.pictures;
  late String _confidence = _initial.confidence;
  late final String _startingCategory =
      _baseRecord?.category ??
      (widget.isSession
          ? 'Sessão'
          : widget.initialCategory ?? _categories.first);
  late String _category = widget.savedDraft?.category ?? _startingCategory;
  late final _startingMission =
      widget.savedDraft?.mission ?? _baseRecord?.mission ?? const MissionPlan();
  late MissionPlan _mission = _startingMission;
  late List<String> _dates =
      widget.savedDraft?.dates ?? _baseRecord?.dates ?? const [];
  late Uint8List? _coverPng = widget.savedDraft?.coverPng;
  bool _choosingCover = false;
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

  NotebookPresentation get _presentation => NotebookPresentation(
    paper: _paper,
    cover: _coverLayout,
    bodyMarks: _body.marks,
    answerMarks: _answer.marks,
    pictures: _pictures,
  );

  Future<void> _chooseImage({bool inline = false}) async {
    if (_saving || _choosingCover) return;
    setState(() => _choosingCover = true);
    try {
      final image = await pickCoverImage(
        maxPngBytes: inline ? 512 * 1024 : 1024 * 1024,
      );
      if (!mounted || image == null) return;
      setState(() {
        if (inline) {
          _pictures = [
            ..._pictures,
            NotebookPicture(
              png: image,
              afterParagraph: notebookParagraphs(_body.text).length - 1,
            ),
          ];
        } else {
          _coverPng = image;
        }
      });
      await _persistDraft();
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Exception catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível abrir a imagem.');
    } finally {
      if (mounted) setState(() => _choosingCover = false);
    }
  }

  Widget _coverFields() {
    final selected = _coverPng;
    final existing = _baseRecord?.coverHash;
    final hasCover = selected == null ? existing != null : selected.isNotEmpty;
    final disabled = _saving || _choosingCover;
    return ExpansionTile(
      title: const Text('Capa do registro'),
      initiallyExpanded: hasCover,
      children: [
        if (hasCover)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: notebookCoverAspectRatio,
              child: selected != null
                  ? CoverFrame(bytes: selected, layout: _coverLayout)
                  : NotebookCoverImage(
                      repository: widget.sync.repository,
                      campaignId: widget.sync.campaignId,
                      hash: existing!,
                      layout: _coverLayout,
                    ),
            ),
          ),
        if (hasCover)
          NotebookCoverControls(
            layout: _coverLayout,
            onChanged: disabled
                ? null
                : (layout) => setState(() => _coverLayout = layout),
            onChangeEnd: () => unawaited(_persistDraft()),
          ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: disabled ? null : _chooseImage,
              icon: const Icon(Icons.image_outlined),
              label: Text(hasCover ? 'Trocar capa' : 'Escolher capa'),
            ),
            if (hasCover)
              TextButton(
                onPressed: disabled
                    ? null
                    : () {
                        setState(() => _coverPng = Uint8List(0));
                        unawaited(_persistDraft());
                      },
                child: const Text('Remover capa'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _pictureFields() => ExpansionTile(
    title: const Text('Imagens no texto'),
    children: [
      for (final (index, picture) in _pictures.indexed)
        ListTile(
          leading: const Icon(Icons.image_outlined),
          title: Text(
            picture.caption.isEmpty ? 'Imagem ${index + 1}' : picture.caption,
          ),
          subtitle: Text(notebookPicturePosition(picture.afterParagraph)),
          onTap: _saving || _choosingCover ? null : () => _editPicture(index),
          trailing: IconButton(
            tooltip: 'Remover imagem ${index + 1} do texto',
            icon: const Icon(Icons.close),
            onPressed: _saving || _choosingCover
                ? null
                : () {
                    setState(() => _pictures = [..._pictures]..removeAt(index));
                    unawaited(_persistDraft());
                  },
          ),
        ),
      const Padding(
        padding: EdgeInsets.all(8),
        child: Text('Separe os parágrafos com uma linha em branco.'),
      ),
      TextButton.icon(
        onPressed: _saving || _choosingCover
            ? null
            : () => _chooseImage(inline: true),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Inserir imagem no texto'),
      ),
    ],
  );

  Future<void> _editPicture(int index) async {
    final picture = _pictures[index];
    final edited = await showDialog<NotebookPicture>(
      context: context,
      barrierDismissible: false,
      builder: (context) => NotebookPictureEditor(
        picture: picture,
        paragraphCount: notebookParagraphs(_body.text).length,
        load: (hash) => widget.sync.repository.readNotebookCover(
          widget.sync.campaignId,
          hash,
        ),
      ),
    );
    if (!mounted || edited == null) return;
    setState(() => _pictures = [..._pictures]..[index] = edited);
    await _persistDraft();
  }

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
    mission: _category == 'Missão' ? _mission : null,
    resolution: _category == 'Investigação' && _confidence == 'Hipótese'
        ? widget.savedDraft?.resolution
        : null,
    coverPng: _coverPng,
    presentation: _presentation,
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
    if (_saving || _confirmingClose || _choosingCover) return;
    if (widget.savedDraft == null &&
        !_savedLocally &&
        _coverPng == null &&
        _presentation.sameAs(_initialPresentation) &&
        _draft == _original &&
        (_category != 'Missão' || identical(_mission, _startingMission)) &&
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
    if (_saving || _confirmingClose || _choosingCover) return;
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
    if (_saving || _choosingCover) return;
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
    final before = previousRecord.presentation;
    final saved = current.presentation;
    if (draft.body == previous.body &&
        sameNotebookMarks(_body.marks, before.bodyMarks)) {
      _body.replaceFormatted(remote.body, saved.bodyMarks);
    }
    if (draft.answer == previous.answer &&
        sameNotebookMarks(_answer.marks, before.answerMarks)) {
      _answer.replaceFormatted(remote.answer, saved.answerMarks);
    }
    setState(() {
      if (draft.confidence == previous.confidence) {
        _confidence = remote.confidence;
      }
      if (listEquals(_dates, previousRecord.dates)) _dates = current.dates;
      if (current.mission case final mission?) {
        _mission = _mission.rebase(
          previousRecord.mission ?? const MissionPlan(),
          mission,
        );
      }
      if (_paper == before.paper) _paper = saved.paper;
      if (sameNotebookPictures(_pictures, before.pictures)) {
        _pictures = saved.pictures;
      }
      if (sameCoverLayout(_coverLayout, before.cover)) {
        _coverLayout = saved.cover;
      }
      _baseRecord = current;
      _current = null;
      _error = null;
    });
    unawaited(_persistDraft());
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    final writingStyle = TextStyle(
      fontFamily: switch (_paper) {
        NotebookPaper.parchment => 'RpgScript',
        NotebookPaper.future => 'RpgMono',
        _ => null,
      },
    );
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
                ? (widget.isSession
                      ? 'Nova crônica'
                      : _startingCategory == 'Missão'
                      ? 'Nova missão'
                      : _startingCategory == 'Investigação' &&
                            widget.initialConfidence == 'Hipótese'
                      ? 'Nova hipótese'
                      : 'Novo registro')
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
                        setState(() => _category = value!);
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
            DropdownButtonFormField<NotebookPaper>(
              key: ValueKey(_paper),
              initialValue: _paper,
              decoration: const InputDecoration(labelText: 'Estilo da página'),
              items: [
                for (final paper in NotebookPaper.values)
                  DropdownMenuItem(value: paper, child: Text(paper.label)),
              ],
              onChanged: _saving
                  ? null
                  : (paper) {
                      setState(() => _paper = paper!);
                      unawaited(_persistDraft());
                    },
            ),
            NotebookFormattingBar(
              controller: _body,
              enabled: !_saving,
              onChanged: () => unawaited(_persistDraft()),
            ),
            TextField(
              controller: _body,
              style: writingStyle,
              enabled: !_saving,
              onChanged: (_) => unawaited(_persistDraft()),
              decoration: const InputDecoration(labelText: 'Texto'),
              minLines: 5,
              maxLines: 16,
            ),
            if (_category == 'Missão')
              MissionFields(
                plan: _mission,
                onChanged: _saving
                    ? null
                    : (plan) {
                        setState(() => _mission = plan);
                        unawaited(_persistDraft());
                      },
              ),
            _coverFields(),
            _pictureFields(),
            NotebookFormattingBar(
              controller: _answer,
              enabled: !_saving,
              onChanged: () => unawaited(_persistDraft()),
            ),
            TextField(
              controller: _answer,
              style: writingStyle,
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
                  if (current.mission case final mission?) ...[
                    MissionSummary(plan: mission),
                    for (final step in mission.steps)
                      ListTile(
                        leading: Icon(
                          step.completed
                              ? Icons.check_box_outlined
                              : Icons.check_box_outline_blank,
                        ),
                        title: Text(step.title),
                        subtitle: step.details.isEmpty
                            ? null
                            : SelectableText(step.details),
                      ),
                  ],
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
