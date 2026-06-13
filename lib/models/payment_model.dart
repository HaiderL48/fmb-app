/// Matches the `payment_receipts` table and the `Payment` interface from mockData.ts
enum PaymentMethod { knet, cash, paymentLink }

extension PaymentMethodExtension on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.knet:
        return 'K-Net';
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.paymentLink:
        return 'Payment Link';
    }
  }

  static PaymentMethod fromString(String value) {
    switch (value.toLowerCase().replaceAll('-', '').replaceAll(' ', '')) {
      case 'knet':
        return PaymentMethod.knet;
      case 'paymentlink':
        return PaymentMethod.paymentLink;
      default:
        return PaymentMethod.cash;
    }
  }
}

enum PaymentStatus { completed, pending, failed }

extension PaymentStatusExtension on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.completed:
        return 'Completed';
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.failed:
        return 'Failed';
    }
  }

  static PaymentStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return PaymentStatus.pending;
      case 'failed':
        return PaymentStatus.failed;
      default:
        return PaymentStatus.completed;
    }
  }
}

class PaymentModel {
  final String id;
  final String userId;
  final double amountKd;
  final PaymentMethod method;
  final DateTime receivedAt;
  final PaymentStatus status;
  final String? receiptNumber; // receiptId / receipt_number
  final String? packageId;
  final String? zabihatId;
  final String? notes;
  final int? misriYear;

  const PaymentModel({
    required this.id,
    required this.userId,
    required this.amountKd,
    required this.method,
    required this.receivedAt,
    required this.status,
    this.receiptNumber,
    this.packageId,
    this.zabihatId,
    this.notes,
    this.misriYear,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      amountKd: (json['amountKd'] as num? ?? json['amount'] as num? ?? 0)
          .toDouble(),
      method: PaymentMethodExtension.fromString(
        json['paymentMethod'] as String? ?? json['method'] as String? ?? 'cash',
      ),
      receivedAt: DateTime.parse(
        json['receivedAt'] as String? ??
            json['date'] as String? ??
            DateTime.now().toIso8601String(),
      ),
      status: PaymentStatusExtension.fromString(
        json['status'] as String? ?? 'completed',
      ),
      receiptNumber:
          json['receiptNumber'] as String? ?? json['receiptId'] as String?,
      packageId: json['packageId'] as String?,
      zabihatId: json['zabihatId'] as String?,
      notes: json['notes'] as String?,
      misriYear: json['misriYear'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'amountKd': amountKd,
    'method': method.label,
    'receivedAt': receivedAt.toIso8601String(),
    'status': status.label,
    'receiptNumber': receiptNumber,
    'packageId': packageId,
    'zabihatId': zabihatId,
    'notes': notes,
    'misriYear': misriYear,
  };

  PaymentModel copyWith({
    String? id,
    String? userId,
    double? amountKd,
    PaymentMethod? method,
    DateTime? receivedAt,
    PaymentStatus? status,
    String? receiptNumber,
    String? packageId,
    String? zabihatId,
    String? notes,
    int? misriYear,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amountKd: amountKd ?? this.amountKd,
      method: method ?? this.method,
      receivedAt: receivedAt ?? this.receivedAt,
      status: status ?? this.status,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      packageId: packageId ?? this.packageId,
      zabihatId: zabihatId ?? this.zabihatId,
      notes: notes ?? this.notes,
      misriYear: misriYear ?? this.misriYear,
    );
  }
}
