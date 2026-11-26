import 'package:material_ui/material_ui.dart';

import 'campaigns.dart';
import 'notebook_sync.dart';

List<T> orderCards<T>(Iterable<T> cards, int? Function(T) position) {
  final rows = [
    for (final (index, card) in cards.indexed)
      (original: index, rank: position(card), card: card),
  ];
  rows.sort((a, b) {
    final order = (a.rank ?? 100001).compareTo(b.rank ?? 100001);
    return order == 0 ? a.original.compareTo(b.original) : order;
  });
  return rows.map((row) => row.card).toList(growable: false);
}

typedef OrderCard = ({String id, String title});

class OrganizeCardsScreen extends StatefulWidget {
  const OrganizeCardsScreen({
    super.key,
    required this.cards,
    required this.save,
    required this.onBack,
    required this.onSaved,
  });

  final List<OrderCard> cards;
  final Future<void> Function(List<String> ids) save;
  final VoidCallback onBack;
  final VoidCallback onSaved;

  @override
  State<OrganizeCardsScreen> createState() => _OrganizeCardsScreenState();
}

class _OrganizeCardsScreenState extends State<OrganizeCardsScreen> {
  late final _cards = [...widget.cards];
  bool _saving = false;
  String? _error;

  void _back() {
    if (!_saving) widget.onBack();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save(_cards.map((card) => card.id).toList(growable: false));
      if (mounted) widget.onSaved();
    } on Exception catch (error) {
      if (mounted) setState(() => _error = organizeMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (popped, _) {
      if (!popped) _back();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Organizar cartões'),
        leading: BackButton(onPressed: _back),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Salvando…' : 'Salvar ordem'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error case final error?)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.all(12),
              itemCount: _cards.length,
              onReorderItem: (from, to) {
                if (_saving) return;
                setState(() => _cards.insert(to, _cards.removeAt(from)));
              },
              itemBuilder: (context, index) {
                final card = _cards[index];
                return Card(
                  key: ValueKey(card.id),
                  child: ListTile(
                    title: Text(
                      card.title.trim().isEmpty ? 'Sem título' : card.title,
                    ),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      enabled: !_saving,
                      child: const Tooltip(
                        message: 'Arrastar',
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

String organizeMessage(Object error) {
  if (isConnectionFailure(error)) {
    return 'Conecte-se à internet e tente novamente.';
  }
  if (error is NotebookConflict) return error.message;
  if (error is GmNoteConflict) {
    return 'A lista mudou. Atualize e tente novamente.';
  }
  return 'Não foi possível concluir. Seus cartões continuam na lista.';
}
