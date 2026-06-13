/// DueStatus Mumin profile from GetMuminDetailsByITSFMB (GET /mumin-fmb/me).
class MuminFmbDetailsModel {
  const MuminFmbDetailsModel({
    required this.hasDetails,
    required this.sabeelNo,
    this.muminName,
    this.ejamaatId,
    this.mobileNo,
    this.email,
    this.incomeCode,
    this.takhmeenKd,
    this.dueKd,
    this.misriYearValue,
  });

  final bool hasDetails;
  final String sabeelNo;
  final String? muminName;
  final String? ejamaatId;
  final String? mobileNo;
  final String? email;
  final String? incomeCode;
  final double? takhmeenKd;
  final double? dueKd;
  final int? misriYearValue;

  int? get misriYear => misriYearValue;

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

  factory MuminFmbDetailsModel.fromJson(Map<String, dynamic> json) {
    return MuminFmbDetailsModel(
      hasDetails: json['hasDetails'] == true,
      sabeelNo: (json['sabeelNo'] ?? '').toString(),
      muminName: json['muminName']?.toString(),
      ejamaatId: json['ejamaatId']?.toString(),
      mobileNo: json['mobileNo']?.toString(),
      email: json['email']?.toString(),
      incomeCode: json['incomeCode']?.toString(),
      takhmeenKd: _asDouble(json['takhmeenKd']),
      dueKd: _asDouble(json['dueKd']),
      misriYearValue: _asInt(json['misriYear']),
    );
  }
}
