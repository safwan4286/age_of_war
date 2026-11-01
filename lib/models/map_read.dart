/// Safe readers for maps from JSON or Hive (Kindose pattern): a missing or
/// wrong field falls back to a default instead of throwing.
extension MapRead on Map<dynamic, dynamic> {
  String str(String key, [String fallback = '']) {
    final v = this[key];
    return v is String ? v : fallback;
  }

  int integer(String key, [int fallback = 0]) {
    final v = this[key];
    if (v is int) return v;
    if (v is num) return v.round();
    return fallback;
  }

  double dbl(String key, [double fallback = 0]) {
    final v = this[key];
    return v is num ? v.toDouble() : fallback;
  }

  bool boolean(String key, [bool fallback = false]) {
    final v = this[key];
    return v is bool ? v : fallback;
  }

  Map<dynamic, dynamic> sub(String key) {
    final v = this[key];
    return v is Map ? v : const {};
  }

  List<Map<dynamic, dynamic>> subs(String key) {
    final v = this[key];
    if (v is! List) return const [];
    return v.whereType<Map<dynamic, dynamic>>().toList();
  }
}
