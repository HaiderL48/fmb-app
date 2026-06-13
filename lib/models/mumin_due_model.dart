/// Latest Takhmin & Due for a Mumin, sourced from the external GetMuminDue
/// system (proxied by our backend at GET /mumin-due/me).
///
/// The backend selects the most recent FMB takhmin row (Laagat like
/// "FMB 1447-48") and returns the parsed Misri year in [misriYear]; non-FMB
/// rows such as "Sabeel" are excluded server-side.
class MuminDueModel {
  const MuminDueModel({
    required this.sabeelNo,
    required this.hasDue,
    this.takhmeenKd,
    this.dueKd,
    this.laagat,
    this.misriYearValue,
    this.muminName,
  });

  final String sabeelNo;

  /// False when the sabil has no FMB takhmin rows in the external system.
  final bool hasDue;

  /// Takhmin (annual contribution) amount in KD.
  final double? takhmeenKd;

  /// Outstanding due amount in KD.
  final double? dueKd;

  /// Raw Laagat label from the source, e.g. "FMB 1447-48".
  final String? laagat;

  /// Misri year provided by the backend (parsed from the FMB Laagat label).
  final int? misriYearValue;

  final String? muminName;

  /// Misri year: backend value when present, else parsed from [laagat]
  /// (handles both "1447" and "FMB 1447-48").
  int? get misriYear {
    if (misriYearValue != null) return misriYearValue;
    final l = laagat?.trim();
    if (l == null || l.isEmpty) return null;
    final match = RegExp(r'\d{4}').allMatches(l);
    for (final m in match) {
      final n = int.tryParse(m.group(0)!);
      if (n != null && n >= 1300 && n <= 1600) return n;
    }
    return null;
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  factory MuminDueModel.fromJson(Map<String, dynamic> json) {
    return MuminDueModel(
      sabeelNo: (json['sabeelNo'] ?? '').toString(),
      hasDue: json['hasDue'] == true,
      takhmeenKd: _asDouble(json['takhmeenKd']),
      dueKd: _asDouble(json['dueKd']),
      laagat: json['laagat']?.toString(),
      misriYearValue: _asInt(json['misriYear']),
      muminName: json['muminName']?.toString(),
    );
  }
}
