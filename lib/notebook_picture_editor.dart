import 'package:flutter/foundation.dart' show Uint8List;
import 'package:material_ui/material_ui.dart';

import 'notebook_format.dart';
import 'picture_background.dart';

const notebookPictureHeight = 210.0;

class NotebookPictureFrame extends StatelessWidget {
  const NotebookPictureFrame({
    super.key,
    required this.bytes,
    required this.layout,
  });

  final Uint8List bytes;
  final PictureLayout layout;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final scale = layout.size * layout.zoom;
        final width = constraints.maxWidth * scale;
        final height = constraints.maxHeight * scale;
        double position(double available, double image, double offset) {
          final gap = available - image;
          return gap * (1 + (gap < 0 ? -offset : offset)) / 2;
        }

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              width: width,
              height: height,
              left: position(constraints.maxWidth, width, layout.x),
              top: position(constraints.maxHeight, height, layout.y),
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                alignment: Alignment(layout.x, layout.y),
                errorBuilder: (_, _, _) =>
                    const Center(child: Icon(Icons.broken_image_outlined)),
              ),
            ),
          ],
        );
      },
    ),
  );
}

String notebookPicturePosition(int index) =>
    index < 0 ? 'Antes do texto' : 'Depois do parágrafo ${index + 1}';

class NotebookPictureEditor extends StatefulWidget {
  const NotebookPictureEditor({
    super.key,
    required this.picture,
    required this.paragraphCount,
    required this.load,
  });

  final NotebookPicture picture;
  final int paragraphCount;
  final Future<Uint8List> Function(String hash) load;

  @override
  State<NotebookPictureEditor> createState() => _NotebookPictureEditorState();
}

class _NotebookPictureEditorState extends State<NotebookPictureEditor> {
  late final Future<Uint8List> _original = _load(
    widget.picture.png,
    widget.picture.hash,
  );
  late Future<Uint8List>? _displayCutout =
      widget.picture.cutoutPng != null || widget.picture.cutoutHash != null
      ? _load(widget.picture.cutoutPng, widget.picture.cutoutHash)
      : null;
  late Uint8List? _newCutout = widget.picture.cutoutPng;
  late String? _cutoutHash = widget.picture.cutoutHash;
  late PictureLayout _layout = widget.picture.layout;
  bool _layoutChanged = false;
  late String _caption = widget.picture.caption;
  late int _position = widget.picture.afterParagraph.clamp(
    -1,
    widget.paragraphCount - 1,
  );
  PictureBackground _background = PictureBackground.automatic;
  double _tolerance = 26;
  bool _showOriginal = false;
  bool _processing = false;
  String? _error;

  Future<Uint8List> _load(Uint8List? bytes, String? hash) async {
    if (bytes != null) return bytes;
    if (hash == null) throw const FormatException('Imagem indisponível.');
    return widget.load(hash).timeout(const Duration(seconds: 12));
  }

  Future<void> _removeBackground() async {
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final cutout = await removePictureBackground(
        await _original,
        _background,
        _tolerance.round(),
      );
      if (!mounted) return;
      setState(() {
        _newCutout = cutout;
        _cutoutHash = null;
        _displayCutout = Future.value(cutout);
        _showOriginal = false;
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Exception {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível abrir a imagem para recortar.',
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _restore() => setState(() {
    _newCutout = null;
    _cutoutHash = null;
    _displayCutout = null;
    _showOriginal = false;
    _error = null;
  });

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    PictureLayout Function(double) change,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      Slider(
        min: min,
        max: max,
        value: value,
        semanticFormatterCallback: (value) =>
            '$label ${value.toStringAsFixed(1)}',
        onChanged: (value) => setState(() {
          _layoutChanged = true;
          _layout = change(value);
        }),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final hasCutout = _displayCutout != null;
    return PopScope(
      canPop: !_processing,
      child: AlertDialog(
        title: const Text('Ajustar imagem'),
        scrollable: true,
        content: SizedBox(
          width: 440,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: SizedBox(
                    height: notebookPictureHeight,
                    child: FutureBuilder(
                      future: _showOriginal
                          ? _original
                          : _displayCutout ?? _original,
                      builder: (context, snapshot) => switch (snapshot) {
                        AsyncSnapshot(
                          connectionState: ConnectionState.done,
                          data: final Uint8List bytes,
                        ) =>
                          NotebookPictureFrame(bytes: bytes, layout: _layout),
                        AsyncSnapshot(hasError: true) => const Center(
                          child: Text('Imagem indisponível.'),
                        ),
                        _ => const Center(child: CircularProgressIndicator()),
                      },
                    ),
                  ),
                ),
              ),
              if (hasCutout)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ver imagem original'),
                  value: _showOriginal,
                  onChanged: _processing
                      ? null
                      : (value) => setState(() => _showOriginal = value),
                ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Remover fundo'),
                children: [
                  DropdownButtonFormField<PictureBackground>(
                    initialValue: _background,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Cor do fundo',
                    ),
                    items: [
                      for (final color in PictureBackground.values)
                        DropdownMenuItem(
                          value: color,
                          child: Text(color.label),
                        ),
                    ],
                    onChanged: _processing
                        ? null
                        : (color) => setState(() => _background = color!),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Tolerância'),
                  ),
                  Slider(
                    min: 4,
                    max: 90,
                    divisions: 86,
                    label: '${_tolerance.round()}',
                    value: _tolerance,
                    onChanged: _processing
                        ? null
                        : (value) => setState(() => _tolerance = value),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _processing ? null : _removeBackground,
                        child: Text(
                          _processing ? 'Processando…' : 'Gerar prévia',
                        ),
                      ),
                      if (hasCutout)
                        TextButton(
                          onPressed: _processing ? null : _restore,
                          child: const Text('Restaurar fundo'),
                        ),
                    ],
                  ),
                  if (_error case final error?) Text(error),
                ],
              ),
              _slider(
                'Tamanho na página',
                _layout.size,
                0.25,
                1,
                (value) => _layout.edit(size: value),
              ),
              _slider(
                'Zoom',
                _layout.zoom,
                1,
                3,
                (value) => _layout.edit(zoom: value),
              ),
              _slider(
                'Posição horizontal',
                _layout.x,
                -1,
                1,
                (value) => _layout.edit(x: value),
              ),
              _slider(
                'Posição vertical',
                _layout.y,
                -1,
                1,
                (value) => _layout.edit(y: value),
              ),
              TextFormField(
                initialValue: _caption,
                decoration: const InputDecoration(labelText: 'Legenda'),
                onChanged: (value) => _caption = value,
              ),
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: _position,
                decoration: const InputDecoration(
                  labelText: 'Posição no texto',
                ),
                items: [
                  for (var i = -1; i < widget.paragraphCount; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(notebookPicturePosition(i)),
                    ),
                ],
                onChanged: (value) => _position = value!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _processing ? null : () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _processing
                ? null
                : () => Navigator.pop(
                    context,
                    widget.picture.edit(
                      caption: _caption,
                      afterParagraph: _position,
                      layout: _layoutChanged ? _layout : null,
                      cutoutHash: _cutoutHash,
                      cutoutPng: _newCutout,
                    ),
                  ),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }
}
