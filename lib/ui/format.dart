/// Display formatting shared by the screens. No locale package: the app's
/// copy is English.
library;

import '../engine/models.dart';
import '../engine/planner.dart' show formatClock, formatDuration;

export '../engine/planner.dart' show formatClock, formatDuration;

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "Monday, 26 October".
String dateLabel(DateTime d) => '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

/// "09:45 – 12:30".
String rangeLabel(DateTime start, DateTime end) => '${formatClock(start)} – ${formatClock(end)}';

/// "Focus", "Body", … "Errand".
String categoryLabel(Category? c) {
  final name = (c ?? Category.rest).name;
  return name[0].toUpperCase() + name.substring(1);
}

/// Capitalises a day type for its chip: "gym" → "Gym".
String dayTypeLabel(String t) => t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);

/// Minutes between two times, rounded up so "1 min left" shows until the end.
int minutesBetween(DateTime from, DateTime to) {
  final seconds = to.difference(from).inSeconds;
  return seconds <= 0 ? 0 : (seconds + 59) ~/ 60;
}

const _ones = [
  'zero',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
  'ten',
  'eleven',
  'twelve',
  'thirteen',
  'fourteen',
  'fifteen',
  'sixteen',
  'seventeen',
  'eighteen',
  'nineteen',
];
const _tens = [
  '',
  '',
  'twenty',
  'thirty',
  'forty',
  'fifty',
  'sixty',
  'seventy',
  'eighty',
  'ninety',
];

/// 0–99 in words ("twenty-five"). Larger numbers stay as digits.
String numberWords(int n) {
  if (n < 0 || n > 99) return '$n';
  if (n < 20) return _ones[n];
  final t = _tens[n ~/ 10];
  return n % 10 == 0 ? t : '$t-${_ones[n % 10]}';
}

String capitalise(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Hours and minutes of sleep, "7h 30".
String sleepLabel(int minutes) => formatDuration(minutes);
