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

class NotebookPicture {
  const NotebookPicture({
    this.hash,
    this.png,
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
        caption: data['caption'] is String ? data['caption'] as String : '',
        afterParagraph: data['afterParagraph'] is int
            ? data['afterParagraph'] as int
            : -1,
        extra: {...data}
          ..remove('path')
          ..remove('localPng')
          ..remove('caption')
          ..remove('afterParagraph'),
      );

  final String? hash;
  final Uint8List? png;
  final String caption;
  final int afterParagraph;
  final Map<String, dynamic> extra;

  NotebookPicture edit({String? caption, int? afterParagraph}) =>
      NotebookPicture(
        hash: hash,
        png: png,
        caption: caption ?? this.caption,
        afterParagraph: afterParagraph ?? this.afterParagraph,
        extra: extra,
      );

  NotebookPicture uploaded(String hash) => NotebookPicture(
    hash: hash,
    caption: caption,
    afterParagraph: afterParagraph,
    extra: extra,
  );

  Map<String, Object?> toJson() => {
    ...extra,
    if (hash != null) 'path': 'rpg-media:$hash',
    if (png != null) 'localPng': base64Encode(png!),
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
