/// A thali service pause window returned from `GET /thali/me/pauses`.
class ThaliPauseModel {
  ThaliPauseModel({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    this.reason,
  });

  final String id;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final String? reason;

  static DateTime _dateOnly(String ymd) {
    final p = ymd.split('-');
    if (p.length == 3) {
      final y = int.tryParse(p[0]);
      final m = int.tryParse(p[1]);
      final d = int.tryParse(p[2]);
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
    return DateTime.parse(ymd);
  }

  factory ThaliPauseModel.fromJson(Map<String, dynamic> json) {
    final startRaw = json['startDate'] ?? json['start_date'];
    final endRaw = json['endDate'] ?? json['end_date'];
    return ThaliPauseModel(
      id: (json['id'] ?? '').toString(),
      startDate: _dateOnly((startRaw ?? '').toString()),
      endDate: _dateOnly((endRaw ?? '').toString()),
      isActive: json['isActive'] == true || json['is_active'] == true,
      reason: json['reason'] as String?,
    );
  }
}
