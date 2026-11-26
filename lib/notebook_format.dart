import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';

typedef NotebookMark = ({int start, int end, Map<String, Object?> attributes});

enum NotebookPaper {
  plain('Leitura simples'),
  parchment('Pergaminho'),
  diary('Diário de Baróvia'),
  future('Futurista');

  const NotebookPaper(this.label);
  final String label;

  static NotebookPaper read(Object? value) =>
      values.firstWhereOrNull((paper) => paper.label == value) ?? plain;
}

List<NotebookMark> readNotebookMarks(Object? value, int length) {
  if (value is! List) return const [];
  return [
    for (final mark in value)
      if (mark
          case {
            'start': final int start,
            'end': final int end,
            'attributes': final Map<String, dynamic> attributes,
          }
          when start >= 0 && end > start && end <= length)
        (start: start, end: end, attributes: Map.unmodifiable(attributes)),
  ];
}

List<Map<String, Object?>> writeNotebookMarks(List<NotebookMark> marks) => [
  for (final mark in marks)
    {'start': mark.start, 'end': mark.end, 'attributes': mark.attributes},
];

bool sameNotebookMarks(List<NotebookMark> left, List<NotebookMark> right) =>
    const DeepCollectionEquality().equals(
      writeNotebookMarks(left),
      writeNotebookMarks(right),
    );

// Offsets use UTF-16, as in Flutter's selection and the legacy data format.
List<NotebookMark> moveNotebookMarks(
  List<NotebookMark> marks,
  String before,
  String after,
) {
  if (before == after || marks.isEmpty) return marks;
  final shorter = before.length < after.length ? before.length : after.length;
  var start = 0;
  while (start < shorter &&
      before.codeUnitAt(start) == after.codeUnitAt(start)) {
    start++;
  }
  var suffix = 0;
  while (suffix < shorter - start &&
      before.codeUnitAt(before.length - 1 - suffix) ==
          after.codeUnitAt(after.length - 1 - suffix)) {
    suffix++;
  }
  final oldEnd = before.length - suffix;
  final newEnd = after.length - suffix;
  final delta = newEnd - oldEnd;
  final updated = <NotebookMark>[];
  for (final mark in marks) {
    if (mark.end <= start) {
      updated.add(mark);
    } else if (mark.start >= oldEnd) {
      updated.add((
        start: mark.start + delta,
        end: mark.end + delta,
        attributes: mark.attributes,
      ));
    } else {
      final left = mark.start < start ? mark.start : start;
      final right = mark.end >= oldEnd ? mark.end + delta : start;
      if (right > left) {
        updated.add((start: left, end: right, attributes: mark.attributes));
      }
    }
  }
  return updated;
}

List<NotebookMark> formatNotebookRange(
  List<NotebookMark> marks,
  int start,
  int end,
  String attribute,
  Object? value,
) => [
  for (final mark in marks)
    if (mark.end <= start ||
        mark.start >= end ||
        !mark.attributes.containsKey(attribute))
      mark
    else ...[
      if (mark.start < start)
        (start: mark.start, end: start, attributes: mark.attributes),
      if (mark.attributes.length > 1)
        (
          start: mark.start < start ? start : mark.start,
          end: mark.end > end ? end : mark.end,
          attributes: {...mark.attributes}..remove(attribute),
        ),
      if (mark.end > end)
        (start: end, end: mark.end, attributes: mark.attributes),
    ],
  if (value != null) (start: start, end: end, attributes: {attribute: value}),
];

final _notebookMediaPath = RegExp(r'^rpg-media:([0-9a-f]{64})$');

String? notebookMediaHash(Object? path) =>
    path is String ? _notebookMediaPath.firstMatch(path)?.group(1) : null;

class PictureLayout {
  const PictureLayout({this.size = 1, this.zoom = 1, this.x = 0, this.y = 0});

  factory PictureLayout.fromJson(Object? data) {
    if (data is! Map) return const PictureLayout();
    double number(String key, double initial, double min, double max) {
      final value = data[key];
      return value is num && value.isFinite
          ? value.clamp(min, max).toDouble()
          : initial;
    }

    final fallbackX = switch (data['align']) {
      'left' => -1.0,
      'right' => 1.0,
      _ => 0.0,
    };
    return PictureLayout(
      size: number('size', 1, 0.25, 1),
      zoom: number('zoom', 1, 1, 3),
      x: number('x', fallbackX, -1, 1),
      y: number('y', 0, -1, 1),
    );
  }

  final double size;
  final double zoom;
  final double x;
  final double y;

  PictureLayout edit({double? size, double? zoom, double? x, double? y}) =>
      PictureLayout(
        size: size ?? this.size,
        zoom: zoom ?? this.zoom,
        x: x ?? this.x,
        y: y ?? this.y,
      );

  Map<String, Object> toJson() => {'size': size, 'zoom': zoom, 'x': x, 'y': y};
}

class NotebookPicture {
  const NotebookPicture({
    this.hash,
    this.png,
    this.cutoutHash,
    this.cutoutPng,
    this.caption = '',
    this.afterParagraph = -1,
    this.extra = const {},
  });

  factory NotebookPicture.fromJson(Map<String, dynamic> data) =>
      NotebookPicture(
        hash: notebookMediaHash(data['path']),
        png: data['localPng'] is String
            ? base64Decode(data['localPng'] as String)
            : null,
        cutoutHash: notebookMediaHash(data['cutoutPath']),
        cutoutPng: data['localCutoutPng'] is String
            ? base64Decode(data['localCutoutPng'] as String)
            : null,
        caption: data['caption'] is String ? data['caption'] as String : '',
        afterParagraph: data['afterParagraph'] is int
            ? data['afterParagraph'] as int
            : -1,
        extra: {...data}
          ..remove('path')
          ..remove('localPng')
          ..remove('cutoutPath')
          ..remove('localCutoutPng')
          ..remove('caption')
          ..remove('afterParagraph'),
      );

  final String? hash;
  final Uint8List? png;
  final String? cutoutHash;
  final Uint8List? cutoutPng;

  String? get displayedHash => cutoutHash ?? hash;
  bool get needsUpload => png != null || cutoutPng != null;
  PictureLayout get layout => PictureLayout.fromJson(extra['look']);
  final String caption;
  final int afterParagraph;
  final Map<String, dynamic> extra;

  NotebookPicture edit({
    required String caption,
    required int afterParagraph,
    PictureLayout? layout,
    String? cutoutHash,
    Uint8List? cutoutPng,
  }) => NotebookPicture(
    hash: hash,
    png: png,
    cutoutHash: cutoutHash,
    cutoutPng: cutoutPng,
    caption: caption,
    afterParagraph: afterParagraph,
    extra: layout == null
        ? extra
        : {
            ...extra,
            'look': {
              if (extra['look'] case final Map look) ...look,
              ...layout.toJson(),
            },
          },
  );

  NotebookPicture uploaded({
    required String? original,
    required String? cutout,
  }) => NotebookPicture(
    hash: original,
    cutoutHash: cutout,
    caption: caption,
    afterParagraph: afterParagraph,
    extra: extra,
  );

  Map<String, Object?> toJson() => {
    ...extra,
    if (hash != null) 'path': 'rpg-media:$hash',
    if (png != null) 'localPng': base64Encode(png!),
    if (cutoutHash != null) 'cutoutPath': 'rpg-media:$cutoutHash',
    if (cutoutPng != null) 'localCutoutPng': base64Encode(cutoutPng!),
    'caption': caption,
    'afterParagraph': afterParagraph,
  };
}

List<NotebookPicture> readNotebookPictures(Object? value) {
  if (value is! List) return const [];
  return [
    for (final map in value.whereType<Map<String, dynamic>>().map(
      NotebookPicture.fromJson,
    ))
      if (map.hash != null || map.png != null) map,
  ];
}

bool sameNotebookPictures(
  List<NotebookPicture> left,
  List<NotebookPicture> right,
) => const DeepCollectionEquality().equals(
  left.map((picture) => picture.toJson()).toList(),
  right.map((picture) => picture.toJson()).toList(),
);

List<({int start, int end})> notebookParagraphs(String body) {
  if (body.isEmpty) return const [];
  var start = 0;
  final ranges = <({int start, int end})>[];
  for (final separator in RegExp(
    r'\r?\n[ \t]*\r?\n(?:[ \t]*\r?\n)*',
  ).allMatches(body)) {
    if (separator.start > start) {
      ranges.add((start: start, end: separator.start));
    }
    start = separator.end;
  }
  if (start < body.length) ranges.add((start: start, end: body.length));
  return ranges;
}
