/// Human-friendly age of the baby at the moment a photo was taken.
///
/// Rolls up sensibly: days → weeks → months → years, e.g. "Newborn",
/// "3 weeks old", "5 months old", "1 year 2 months". Returns an empty string
/// when we have no birthdate or the photo predates it.
String ageAt(DateTime? birth, DateTime when) {
  if (birth == null) return '';
  final b = DateTime(birth.year, birth.month, birth.day);
  final w = DateTime(when.year, when.month, when.day);
  if (w.isBefore(b)) return '';

  final days = w.difference(b).inDays;
  if (days == 0) return 'Newborn';
  if (days < 14) return '$days ${days == 1 ? 'day' : 'days'} old';
  if (days < 56) {
    final weeks = days ~/ 7;
    return '$weeks weeks old';
  }

  var months = (w.year - b.year) * 12 + (w.month - b.month);
  if (w.day < b.day) months -= 1;
  if (months < 1) months = 1;

  if (months < 24) return '$months months old';

  final years = months ~/ 12;
  final rem = months % 12;
  if (rem == 0) return '$years ${years == 1 ? 'year' : 'years'} old';
  return '$years ${years == 1 ? 'yr' : 'yrs'} $rem mo';
}

/// A short heading for a day, e.g. "Today", "Yesterday", or "12 March 2026".
String dayLabel(DateTime when) {
  final now = DateTime.now();
  final d = DateTime(when.year, when.month, when.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
