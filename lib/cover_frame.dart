import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import 'campaigns.dart';

const notebookCoverAspectRatio = 2.65;

class CoverFrame extends StatelessWidget {
  const CoverFrame({super.key, required this.bytes, required this.layout});

  final Uint8List bytes;
  final CampaignCoverLayout layout;

  @override
  Widget build(BuildContext context) {
    final alignment = layout.fill
        ? Alignment(layout.x, layout.y)
        : Alignment.center;
    return ClipRect(
      child: ColoredBox(
        color: const Color(0xff211913),
        child: Transform.scale(
          scale: layout.fill ? layout.zoom : 1,
          alignment: alignment,
          child: SizedBox.expand(
            child: Image.memory(
              bytes,
              fit: layout.fill ? BoxFit.cover : BoxFit.contain,
              alignment: alignment,
              errorBuilder: (_, _, _) =>
                  const Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        ),
      ),
    );
  }
}

class NotebookCoverControls extends StatelessWidget {
  const NotebookCoverControls({
    super.key,
    required this.layout,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final CampaignCoverLayout layout;
  final ValueChanged<CampaignCoverLayout>? onChanged;
  final VoidCallback onChangeEnd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Preencher o cartão'),
        subtitle: Text(
          layout.fill ? 'Recortar e ajustar' : 'Mostrar a imagem inteira',
        ),
        value: layout.fill,
        onChanged: onChanged == null
            ? null
            : (fill) {
                onChanged!(
                  CampaignCoverLayout(
                    fill: fill,
                    zoom: layout.zoom,
                    x: layout.x,
                    y: layout.y,
                  ),
                );
                onChangeEnd();
              },
      ),
      if (layout.fill) ...[
        _slider(
          'Zoom',
          layout.zoom,
          1,
          3,
          (value) => CampaignCoverLayout(zoom: value, x: layout.x, y: layout.y),
        ),
        _slider(
          'Posição horizontal',
          layout.x,
          -1,
          1,
          (value) =>
              CampaignCoverLayout(zoom: layout.zoom, x: value, y: layout.y),
        ),
        _slider(
          'Posição vertical',
          layout.y,
          -1,
          1,
          (value) =>
              CampaignCoverLayout(zoom: layout.zoom, x: layout.x, y: value),
        ),
      ],
    ],
  );

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    CampaignCoverLayout Function(double) update,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      Slider(
        value: value,
        min: min,
        max: max,
        semanticFormatterCallback: (value) =>
            '$label ${value.toStringAsFixed(1)}',
        onChanged: onChanged == null
            ? null
            : (value) => onChanged!(update(value)),
        onChangeEnd: onChanged == null ? null : (_) => onChangeEnd(),
      ),
    ],
  );
}
