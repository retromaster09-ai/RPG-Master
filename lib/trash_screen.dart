import 'package:material_ui/material_ui.dart';

import 'campaigns.dart';
import 'notebook_sync.dart';

Future<bool> confirmMoveToTrash(BuildContext context, String title) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mover para a lixeira?'),
        content: Text(title.trim().isEmpty ? 'Registro sem título' : title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mover'),
          ),
        ],
      ),
    ) ==
    true;

String trashMessage(Object error) {
  if (isConnectionFailure(error)) {
    return 'Conecte-se à internet para atualizar a lixeira.';
  }
  if (error is NotebookConflict) return error.message;
  if (error is GmNoteConflict) {
    return 'A nota mudou. Atualize a lista e tente novamente.';
  }
  return 'Não foi possível atualizar a lixeira. Tente novamente.';
}

class TrashScreen<T> extends StatefulWidget {
  const TrashScreen({
    super.key,
    required this.title,
    required this.load,
    required this.itemTitle,
    required this.itemCategory,
    required this.restore,
    required this.onBack,
  });

  final String title;
  final Future<List<T>> Function() load;
  final String Function(T) itemTitle;
  final String? Function(T) itemCategory;
  final Future<void> Function(T) restore;
  final VoidCallback onBack;

  @override
  State<TrashScreen<T>> createState() => _TrashScreenState<T>();
}

class _TrashScreenState<T> extends State<TrashScreen<T>> {
  late Future<List<T>> _items = widget.load();
  bool _restoring = false;

  void _refresh() {
    final items = widget.load();
    setState(() {
      _items = items;
    });
  }

  Future<void> _restore(T item) async {
    if (_restoring) return;
    setState(() => _restoring = true);
    try {
      await widget.restore(item);
      if (mounted) {
        _refresh();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Registro restaurado.')));
      }
    } on Exception catch (error) {
      if (mounted) {
        _refresh();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(trashMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  void _back() {
    if (!_restoring) widget.onBack();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (popped, _) {
      if (!popped) _back();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: BackButton(onPressed: _back),
        actions: [
          IconButton(
            onPressed: _restoring ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar lixeira',
          ),
        ],
      ),
      body: FutureBuilder<List<T>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                trashMessage(snapshot.error!),
                textAlign: TextAlign.center,
              ),
            );
          }
          final items = snapshot.requireData;
          if (items.isEmpty) {
            return const Center(child: Text('A lixeira está vazia.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final title = widget.itemTitle(item);
              final category = widget.itemCategory(item);
              return Card(
                child: ListTile(
                  title: Text(title.trim().isEmpty ? 'Sem título' : title),
                  subtitle: category == null ? null : Text(category),
                  trailing: IconButton(
                    onPressed: _restoring ? null : () => _restore(item),
                    icon: const Icon(Icons.restore_from_trash_outlined),
                    tooltip: 'Restaurar',
                  ),
                ),
              );
            },
          );
        },
      ),
    ),
  );
}
