import 'payment_model.dart';

/// One receipt row from DueStatus GetRecieptDetailsByITSFMB.
class ExternalReceiptModel {
  const ExternalReceiptModel({
    required this.receiptNumber,
    required this.receiptDate,
    required this.amountKd,
    this.sabeelNo,
    this.ejamaatId,
    this.trackId,
    this.laagatName,
    this.receiptNo,
  });

  final String? sabeelNo;
  final String? ejamaatId;
  final String receiptNumber;
  final String receiptDate;
  final double amountKd;
  final String? trackId;
  final String? laagatName;
  final int? receiptNo;

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? 0;
    return 0;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  factory ExternalReceiptModel.fromJson(Map<String, dynamic> json) {
    return ExternalReceiptModel(
      sabeelNo: json['sabeelNo']?.toString(),
      ejamaatId: json['ejamaatId']?.toString(),
      receiptNumber: (json['receiptNumber'] ?? '').toString(),
      receiptDate: (json['receiptDate'] ?? '').toString(),
      amountKd: _asDouble(json['amountKd']),
      trackId: json['trackId']?.toString(),
      laagatName: json['laagatName']?.toString(),
      receiptNo: _asInt(json['receiptNo']),
    );
  }

  /// Map to [PaymentModel] for existing Home recent-payments UI.
  PaymentModel toPaymentModel({required String userId}) {
    return PaymentModel(
      id: trackId ?? receiptNumber,
      userId: userId,
      amountKd: amountKd,
      method: PaymentMethod.knet,
      receivedAt: _parseReceiptDate(receiptDate),
      status: PaymentStatus.completed,
      receiptNumber: receiptNumber,
      notes: laagatName,
    );
  }

  static DateTime _parseReceiptDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return DateTime.now();
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso.toLocal();

    final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
    if (slash != null) {
      final d = int.parse(slash.group(1)!);
      final m = int.parse(slash.group(2)!);
      final y = int.parse(slash.group(3)!);
      return DateTime(y, m, d);
    }

    final dash = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
    if (dash != null) {
      return DateTime(
        int.parse(dash.group(1)!),
        int.parse(dash.group(2)!),
        int.parse(dash.group(3)!),
      );
    }
    return DateTime.now();
  }
}
