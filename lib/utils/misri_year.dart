/// FMB takhmin year label for a Misri (Hijri) year: the year plus the next
/// year's last two digits, e.g. 1447 -> "1447-48", 1448 -> "1448-49".
///
/// Returns an em dash for null/invalid input.
String formatMisriYear(int? year) {
  if (year == null) return '—';
  final next = (((year + 1) % 100) + 100) % 100;
  return '$year-${next.toString().padLeft(2, '0')}';
}
