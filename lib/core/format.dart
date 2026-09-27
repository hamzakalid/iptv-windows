String formatDuration(int? secs) {
  if (secs == null || secs <= 0) return '';
  final h = secs ~/ 3600;
  final m = (secs % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

String formatClock(DateTime? t) {
  if (t == null) return '';
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String formatCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

String timeAgo(DateTime? t) {
  if (t == null) return 'never';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

/// Media timecode: "41:12", or "1:02:03" past the hour.
String formatTimecode(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final x = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$x' : '$m:$x';
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// History timestamps: "Today · 17:40", "Yesterday · 22:10", "Sat · 21:15",
/// then a plain date.
String formatWhen(DateTime? t) {
  if (t == null) return '';
  final now = DateTime.now();
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  final clock = formatClock(t);
  if (days <= 0) return 'Today · $clock';
  if (days == 1) return 'Yesterday · $clock';
  if (days < 7) return '${_weekdays[t.weekday - 1]} · $clock';
  return '${t.day} ${_months[t.month - 1]}';
}
