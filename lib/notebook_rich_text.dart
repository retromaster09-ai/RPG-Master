import 'package:material_ui/material_ui.dart';

import 'notebook_format.dart';

TextSpan notebookTextSpan(
  String text,
  List<NotebookMark> marks,
  TextStyle? style, {
  TextRange? composing,
  bool lightPaper = false,
}) {
  final spanBounds = <int>{0, text.length};
  for (final mark in marks) {
    spanBounds.addAll([mark.start, mark.end]);
  }
  if (composing != null) spanBounds.addAll([composing.start, composing.end]);
  final bounds = spanBounds.toList()..sort();
  return TextSpan(
    style: style,
    children: [
      for (var index = 1; index < bounds.length; index++)
        _styledSpan(
          text,
          bounds[index - 1],
          bounds[index],
          marks,
          style,
          composing,
          lightPaper,
        ),
    ],
  );
}

TextSpan _styledSpan(
  String text,
  int start,
  int end,
  List<NotebookMark> marks,
  TextStyle? base,
  TextRange? composing,
  bool lightPaper,
) {
  final attributes = {
    for (final mark in marks)
      if (mark.start <= start && mark.end >= end) ...mark.attributes,
  };
  final heading = attributes['heading'];
  final color = switch (attributes['color']) {
    'wine' => lightPaper ? const Color(0xff822d45) : const Color(0xffef9caf),
    'blue' => lightPaper ? const Color(0xff214d83) : const Color(0xffa4c9ff),
    'teal' => lightPaper ? const Color(0xff16564c) : const Color(0xff80dac7),
    'purple' => lightPaper ? const Color(0xff604085) : const Color(0xffd8b9ff),
    _ => null,
  };
  final highlight = switch (attributes['highlight']) {
    'gold' => const Color(0xffffdf8c),
    'rose' => const Color(0xfffbc5d1),
    'mint' => const Color(0xffb2ead8),
    _ => null,
  };
  return TextSpan(
    text: text.substring(start, end),
    style: TextStyle(
      fontWeight: attributes['bold'] == true || heading == 1 || heading == 2
          ? FontWeight.bold
          : null,
      fontStyle: attributes['italic'] == true ? FontStyle.italic : null,
      fontSize: switch (heading) {
        1 => (base?.fontSize ?? 16) * 1.38,
        2 => (base?.fontSize ?? 16) * 1.2,
        _ => null,
      },
      backgroundColor: highlight,
      color: highlight == null ? color : const Color(0xff271b14),
      decoration:
          composing != null && start >= composing.start && end <= composing.end
          ? TextDecoration.underline
          : null,
    ),
  );
}

class NotebookTextController extends TextEditingController {
  NotebookTextController(String text, this.marks) : super(text: text);

  List<NotebookMark> marks;

  @override
  set value(TextEditingValue next) {
    marks = moveNotebookMarks(marks, value.text, next.text);
    super.value = next;
  }

  void replaceFormatted(String content, List<NotebookMark> newMarks) {
    marks = newMarks;
    super.value = TextEditingValue(text: content);
  }

  void apply(String attribute, Object? setting) {
    if (!selection.isValid || selection.isCollapsed) return;
    marks = formatNotebookRange(
      marks,
      selection.start,
      selection.end,
      attribute,
      setting,
    );
    notifyListeners();
  }

  void toggleBullets() {
    final selected = selection;
    if (!selected.isValid) return;
    const bullet = '• ';
    final original = text;
    final first = selected.start == 0
        ? 0
        : original.lastIndexOf('\n', selected.start - 1) + 1;
    final lines = [first];
    for (var i = first; i + 1 < selected.end; i++) {
      if (original.codeUnitAt(i) == 10) lines.add(i + 1);
    }
    final remove = lines.every((line) => original.startsWith(bullet, line));
    var updated = original;
    var start = selected.start;
    var end = selected.end;
    for (final line in lines.reversed) {
      if (!remove && updated.startsWith(bullet, line)) continue;
      final next = remove
          ? updated.replaceRange(line, line + bullet.length, '')
          : updated.replaceRange(line, line, bullet);
      int move(int offset) {
        if (offset < line) return offset;
        if (!remove) return offset + bullet.length;
        return offset - line < bullet.length ? line : offset - bullet.length;
      }

      start = move(start);
      end = move(end);
      marks = moveNotebookMarks(marks, updated, next);
      updated = next;
    }
    super.value = TextEditingValue(
      text: updated,
      selection: TextSelection(
        baseOffset: selected.baseOffset <= selected.extentOffset ? start : end,
        extentOffset: selected.baseOffset <= selected.extentOffset
            ? end
            : start,
      ),
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) => notebookTextSpan(
    text,
    marks,
    style,
    composing: withComposing && value.isComposingRangeValid
        ? value.composing
        : null,
  );
}

class NotebookFormattingBar extends StatelessWidget {
  const NotebookFormattingBar({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final NotebookTextController controller;
  final bool enabled;
  final VoidCallback onChanged;

  void _apply(String attribute, Object? value) {
    controller.apply(attribute, value);
    onChanged();
  }

  @override
  Widget build(BuildContext context) => TextFieldTapRegion(
    child: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final selection = controller.selection;
        final canFormat =
            enabled && selection.isValid && !selection.isCollapsed;
        bool marked(String key) => controller.marks.any(
          (mark) =>
              mark.start <= selection.start &&
              mark.end >= selection.end &&
              mark.attributes[key] == true,
        );
        return Wrap(
          spacing: 2,
          children: [
            IconButton(
              tooltip: 'Negrito',
              icon: const Icon(Icons.format_bold),
              isSelected: canFormat && marked('bold'),
              onPressed: canFormat
                  ? () => _apply('bold', marked('bold') ? null : true)
                  : null,
            ),
            IconButton(
              tooltip: 'Itálico',
              icon: const Icon(Icons.format_italic),
              isSelected: canFormat && marked('italic'),
              onPressed: canFormat
                  ? () => _apply('italic', marked('italic') ? null : true)
                  : null,
            ),
            PopupMenuButton<int>(
              enabled: canFormat,
              tooltip: 'Título do trecho',
              icon: const Icon(Icons.title),
              onSelected: (style) =>
                  _apply('heading', style == 0 ? null : style),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 1, child: Text('Título grande')),
                PopupMenuItem(value: 2, child: Text('Subtítulo')),
                PopupMenuItem(value: 0, child: Text('Texto normal')),
              ],
            ),
            IconButton(
              tooltip: 'Lista com marcadores',
              icon: const Icon(Icons.format_list_bulleted),
              onPressed: enabled && selection.isValid
                  ? () {
                      controller.toggleBullets();
                      onChanged();
                    }
                  : null,
            ),
            _colorMenu(
              'color',
              'Cor do texto',
              Icons.format_color_text,
              canFormat,
              const {
                'theme': 'Padrão',
                'wine': 'Vinho',
                'blue': 'Azul',
                'teal': 'Verde',
                'purple': 'Roxo',
              },
            ),
            _colorMenu(
              'highlight',
              'Destaque',
              Icons.format_color_fill,
              canFormat,
              const {
                'none': 'Sem destaque',
                'gold': 'Dourado',
                'rose': 'Rosa',
                'mint': 'Menta',
              },
            ),
          ],
        );
      },
    ),
  );

  Widget _colorMenu(
    String attribute,
    String label,
    IconData icon,
    bool enabled,
    Map<String, String> options,
  ) => PopupMenuButton<String>(
    enabled: enabled,
    tooltip: label,
    icon: Icon(icon),
    onSelected: (value) =>
        _apply(attribute, value == 'theme' || value == 'none' ? null : value),
    itemBuilder: (_) => [
      for (final option in options.entries)
        PopupMenuItem(value: option.key, child: Text(option.value)),
    ],
  );
}
