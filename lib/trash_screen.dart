import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  if (error is GmNoteConflict ||
      (error is PostgrestException && error.code == '40001')) {
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
    this.permanentlyDelete,
    required this.onBack,
  });

  final String title;
  final Future<List<T>> Function() load;
  final String Function(T) itemTitle;
  final String? Function(T) itemCategory;
  final Future<void> Function(T) restore;
  final Future<void> Function(T)? permanentlyDelete;
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

  Future<void> _confirmDelete(T item) async {
    final name = widget.itemTitle(item);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir definitivamente?'),
        content: Text(
          '“$name” será removido do caderno e do histórico da campanha. Esta ação é irreversível no app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir de vez'),
          ),
        ],
      ),
    );
    if (mounted && accepted == true) await _change(item, delete: true);
  }

  Future<void> _change(T item, {bool delete = false}) async {
    if (_restoring) return;
    setState(() => _restoring = true);
    try {
      await (delete ? widget.permanentlyDelete!(item) : widget.restore(item));
      if (mounted) {
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              delete
                  ? 'Registro excluído definitivamente.'
                  : 'Registro restaurado.',
            ),
          ),
        );
      }
    } catch (error) {
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _restoring ? null : () => _change(item),
                        icon: const Icon(Icons.restore_from_trash_outlined),
                        tooltip: 'Restaurar',
                      ),
                      if (widget.permanentlyDelete != null)
                        IconButton(
                          onPressed: _restoring
                              ? null
                              : () => _confirmDelete(item),
                          icon: const Icon(Icons.delete_forever_outlined),
                          tooltip: 'Excluir definitivamente',
                        ),
                    ],
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
