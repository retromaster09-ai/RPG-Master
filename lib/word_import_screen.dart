import 'package:diacritic/diacritic.dart';
import 'package:material_ui/material_ui.dart';

import 'campaigns.dart';
import 'mission_fields.dart';
import 'missions.dart';
import 'session_dates.dart';
import 'word_import.dart';

class WordImportScreen extends StatefulWidget {
  const WordImportScreen({
    super.key,
    required this.campaign,
    required this.preview,
    required this.notebook,
    required this.onClose,
    required this.onImport,
  });

  final Campaign campaign;
  final WordImportPreview preview;
  final Notebook notebook;
  final VoidCallback onClose;
  final Future<void> Function(List<CampaignRecord>) onImport;

  @override
  State<WordImportScreen> createState() => _WordImportScreenState();
}

class _WordImportScreenState extends State<WordImportScreen> {
  late final _records = [...widget.preview.records];
  late final _existing = [
    ...widget.notebook.records,
    ...widget.notebook.sessions,
    ...widget.notebook.trash,
  ];
  late final _existingKeys = _existing.map(notebookImportContentKey).toSet();
  late final _selected = _initialSelection();
  bool _saving = false;
  String? _error;

  String _titleKey(CampaignRecord row) =>
      '${row.category}:${removeDiacritics(row.title.trim().toLowerCase())}';

  Set<String> _initialSelection() {
    final knownKeys = {..._existingKeys};
    final titles = _existing.map(_titleKey).toSet();
    return {
      for (final row in _records)
        if (_selectable(row) &&
            knownKeys.add(notebookImportContentKey(row)) &&
            titles.add(_titleKey(row)))
          row.id!,
    };
  }

  bool _identical(CampaignRecord row) =>
      _existingKeys.contains(notebookImportContentKey(row));

  bool _selectable(CampaignRecord row) =>
      row.category != null &&
      !_identical(row) &&
      (row.title.trim().isNotEmpty ||
          row.body.trim().isNotEmpty ||
          row.answer.trim().isNotEmpty);

  Future<void> _edit(int index) async {
    final updated = await Navigator.of(context).push<CampaignRecord>(
      MaterialPageRoute(
        builder: (_) => _ReviewWordRecord(record: _records[index]),
      ),
    );
    if (!mounted || updated == null) return;
    setState(() {
      _records[index] = updated;
      if (!_selectable(updated)) _selected.remove(updated.id);
    });
  }

  Future<void> _import() async {
    final selection = _records
        .where((row) => _selected.contains(row.id) && _selectable(row))
        .toList();
    if (selection.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onImport(selection);
    } on NotebookConflict catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Exception {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível salvar na campanha. Confira a conexão e tente de novo.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = <String, int>{};
    for (final row in [..._existing, ..._records]) {
      titles.update(_titleKey(row), (count) => count + 1, ifAbsent: () => 1);
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && !_saving) widget.onClose();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _saving ? null : widget.onClose),
          title: const Text('Revisar importação do Word'),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _records.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.campaign.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Text(
                      'Os registros selecionados ficam visíveis aos participantes da campanha.',
                    ),
                    if (widget.preview.hasImages)
                      const Text(
                        'Este Word contém imagens. A importação inclui o conteúdo em texto.',
                      ),
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                              if (_selected.isEmpty) {
                                _selected.addAll(_initialSelection());
                              } else {
                                _selected.clear();
                              }
                            }),
                      child: Text(
                        _selected.isEmpty
                            ? 'Selecionar sugestões'
                            : 'Limpar seleção',
                      ),
                    ),
                  ],
                ),
              );
            }
            final row = _records[index - 1];
            final identical = _identical(row);
            final category = wordImportSections[row.category];
            final sameTitle = (titles[_titleKey(row)] ?? 0) > 1;
            return Card(
              child: ListTile(
                leading: Checkbox(
                  value: _selected.contains(row.id),
                  semanticLabel: 'Importar ${row.title}',
                  onChanged: _saving || !_selectable(row)
                      ? null
                      : (value) => setState(() {
                          if (value == true) {
                            _selected.add(row.id!);
                          } else {
                            _selected.remove(row.id);
                          }
                        }),
                ),
                title: Text(
                  row.title.trim().isEmpty ? 'Sem título' : row.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    category ?? 'Escolha a seção',
                    if (identical)
                      'Registro idêntico já na campanha'
                    else if (sameTitle)
                      'Confira o título repetido',
                    if (row.confidence == 'Hipótese') 'Hipótese',
                    if (row.dates.isNotEmpty)
                      row.dates.map(sessionDateLabel).join(' · '),
                    if (row.mission case final mission?)
                      '${mission.status.label} · ${mission.steps.length} etapas',
                    if (row.body.isNotEmpty) row.body,
                  ].join('\n'),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'Revisar registro',
                  onPressed: _saving ? null : () => _edit(index - 1),
                  icon: const Icon(Icons.edit_outlined),
                ),
                onTap: _saving ? null : () => _edit(index - 1),
              ),
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error case final error?) Text(error),
              FilledButton(
                onPressed: _saving || _selected.isEmpty ? null : _import,
                child: Text(
                  _saving
                      ? 'Salvando…'
                      : 'Importar ${_selected.length} para a campanha',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewWordRecord extends StatefulWidget {
  const _ReviewWordRecord({required this.record});
  final CampaignRecord record;

  @override
  State<_ReviewWordRecord> createState() => _ReviewWordRecordState();
}

class _ReviewWordRecordState extends State<_ReviewWordRecord> {
  late final _title = TextEditingController(text: widget.record.title);
  late final _body = TextEditingController(text: widget.record.body);
  late final _answer = TextEditingController(text: widget.record.answer);
  late final _dates = TextEditingController(
    text: widget.record.dates.map(sessionDateLabel).join(', '),
  );
  late String? _category = widget.record.category;
  late bool _hypothesis = widget.record.confidence == 'Hipótese';
  late MissionPlan _mission = widget.record.mission ?? const MissionPlan();
  String? _dateError;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _answer.dispose();
    _dates.dispose();
    super.dispose();
  }

  void _apply() {
    final dates = _category == 'Sessão'
        ? readWordDates(_dates.text)
        : const <String>[];
    if (dates == null) {
      setState(() => _dateError = 'Use datas válidas no formato DD/MM/AAAA.');
      return;
    }
    Navigator.pop(
      context,
      CampaignRecord(
        _title.text.trim(),
        _body.text.trim(),
        id: widget.record.id,
        category: _category,
        answer: _answer.text.trim(),
        confidence: _hypothesis && _category == 'Investigação'
            ? 'Hipótese'
            : null,
        dates: dates,
        mission: _category == 'Missão' ? _mission : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Revisar registro')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _category,
          isExpanded: true,
          hint: const Text('Escolha a seção'),
          decoration: const InputDecoration(labelText: 'Seção de destino'),
          items: [
            for (final entry in wordImportSections.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (category) => setState(() => _category = category),
        ),
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Título'),
        ),
        TextField(
          controller: _body,
          decoration: const InputDecoration(labelText: 'Texto'),
          minLines: 3,
          maxLines: 12,
        ),
        if (_category == 'Investigação')
          SwitchListTile(
            title: const Text('Hipótese'),
            value: _hypothesis,
            onChanged: (value) => setState(() => _hypothesis = value),
          ),
        if (_category == 'Investigação' || _answer.text.isNotEmpty)
          TextField(
            controller: _answer,
            decoration: const InputDecoration(labelText: 'Resposta'),
            maxLines: 5,
            minLines: 2,
          ),
        if (_category == 'Sessão')
          TextField(
            controller: _dates,
            decoration: InputDecoration(
              labelText: 'Datas da crônica',
              helperText: 'DD/MM/AAAA. Separe várias datas com vírgula.',
              errorText: _dateError,
            ),
          ),
        if (_category == 'Missão')
          MissionFields(
            plan: _mission,
            onChanged: (mission) => setState(() => _mission = mission),
          ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(12),
      child: FilledButton(
        onPressed: _apply,
        child: const Text('Aplicar revisão'),
      ),
    ),
  );
}
