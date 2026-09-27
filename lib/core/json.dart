// Lenient JSON readers. The backend passes through a lot of upstream
// (Xtream / M3U) data, so numbers sometimes arrive as strings and fields
// are frequently missing. These helpers never throw.

typedef Json = Map<String, dynamic>;

String? jStr(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

double? jDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int? jInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.round();
  final parsed = num.tryParse(v.toString());
  return parsed?.round();
}

bool jBool(Object? v) => v == true || v == 1 || v == 'true' || v == '1';

DateTime? jDate(Object? v) {
  final s = jStr(v);
  return s == null ? null : DateTime.tryParse(s)?.toLocal();
}

Json? jMap(Object? v) => v is Map ? v.cast<String, dynamic>() : null;

List<Json> jMapList(Object? v) =>
    v is List ? v.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList() : const [];

List<String> jStrList(Object? v) {
  if (v is List) return v.map(jStr).whereType<String>().toList();
  final s = jStr(v);
  if (s == null) return const [];
  return s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}
