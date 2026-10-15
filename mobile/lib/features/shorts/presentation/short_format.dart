// lib/features/shorts/presentation/short_format.dart
const _months = [
  'जनवरी', 'फ़रवरी', 'मार्च', 'अप्रैल', 'मई', 'जून',
  'जुलाई', 'अगस्त', 'सितंबर', 'अक्टूबर', 'नवंबर', 'दिसंबर',
];

/// "15 अक्टूबर 2026, 17:30" — date AND time, as required for news freshness.
String formatDateTimeHi(DateTime d) {
  final t = d.toLocal();
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '${t.day} ${_months[t.month - 1]} ${t.year}, $hh:$mm';
}

String formatDateHi(DateTime d) {
  final t = d.toLocal();
  return '${t.day} ${_months[t.month - 1]} ${t.year}';
}

/// Short relative label for the feed ("2 घंटे पहले"), falling back to the full date.
String relativeHi(DateTime d, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(d);
  if (diff.isNegative || diff.inMinutes < 1) return 'अभी';
  if (diff.inMinutes < 60) return '${diff.inMinutes} मिनट पहले';
  if (diff.inHours < 24) return '${diff.inHours} घंटे पहले';
  if (diff.inDays < 7) return '${diff.inDays} दिन पहले';
  return formatDateHi(d);
}

/// News older than this is labelled as old so it is never mistaken for breaking news.
bool isStaleNews(DateTime? publishedAt, {DateTime? now, Duration threshold = const Duration(hours: 48)}) {
  if (publishedAt == null) return false;
  return (now ?? DateTime.now()).difference(publishedAt) > threshold;
}
