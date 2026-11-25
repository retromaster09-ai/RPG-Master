final _datePrefix = RegExp(r'^(\d{4})-(\d{2})-(\d{2})T');

DateTime? sessionDay(String value) {
  final match = _datePrefix.firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final date = DateTime(year, month, day);
  return year > 0 && date.year == year && date.month == month && date.day == day
      ? date
      : null;
}

List<String> readSessionDates(Object? data) => data is List
    ? List.unmodifiable(
        data.whereType<String>().where((date) => sessionDay(date) != null),
      )
    : const [];

String sessionDateValue(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day).toIso8601String();

String sessionDateLabel(String value) {
  final date = sessionDay(value);
  if (date == null) return value;
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year.toString().padLeft(4, '0')}';
}

String? firstSessionDay(List<String> dates) {
  String? first;
  for (final date in dates) {
    final day = date.substring(0, 10);
    if (first == null || day.compareTo(first) < 0) first = day;
  }
  return first;
}
