enum UPaymentStatus { captured, declined, pending, cancelled, failed }

extension UPaymentStatusX on UPaymentStatus {
  bool get isSuccess => this == UPaymentStatus.captured;

  String get label {
    switch (this) {
      case UPaymentStatus.captured:
        return 'Captured';
      case UPaymentStatus.declined:
        return 'Declined';
      case UPaymentStatus.pending:
        return 'Pending';
      case UPaymentStatus.cancelled:
        return 'Cancelled';
      case UPaymentStatus.failed:
        return 'Failed';
    }
  }
}

class UPaymentResultModel {
  final UPaymentStatus status;
  final String orderId;
  final String? message;

  const UPaymentResultModel({
    required this.status,
    required this.orderId,
    this.message,
  });

  static UPaymentStatus fromApiStatus(String? value) {
    final normalized = (value ?? '').trim().toUpperCase();
    switch (normalized) {
      case 'CAPTURED':
        return UPaymentStatus.captured;
      case 'DECLINED':
      case 'ERROR':
        return UPaymentStatus.declined;
      case 'ABANDONED':
      case 'CANCELLED':
        return UPaymentStatus.cancelled;
      case 'PENDING':
        return UPaymentStatus.pending;
      default:
        return UPaymentStatus.failed;
    }
  }
}

class UPaymentInitiateModel {
  final String orderId;
  final String paymentUrl;
  final String? merchantReferenceId;
  final bool reusedPending;

  const UPaymentInitiateModel({
    required this.orderId,
    required this.paymentUrl,
    this.merchantReferenceId,
    this.reusedPending = false,
  });

  static UPaymentInitiateModel fromApi(Map<String, dynamic> data) {
    final nested = data['data'] as Map<String, dynamic>?;
    final resolvedPaymentUrl =
        (data['paymentUrl'] ??
                data['paymentURL'] ??
                data['link'] ??
                data['url'] ??
                nested?['paymentUrl'] ??
                nested?['paymentURL'] ??
                nested?['link'] ??
                nested?['url'])
            ?.toString()
            .trim();
    final resolvedOrderId =
        _toCleanString(data['orderId']) ?? _toCleanString(nested?['orderId']);
    final merchantReferenceId =
        _toCleanString(data['merchantReferenceId']) ??
        _toCleanString(nested?['merchantReferenceId']);
    final reusedPending =
        _toBool(data['reusedPending']) ??
        _toBool(nested?['reusedPending']) ??
        false;

    if ((resolvedPaymentUrl ?? '').isEmpty || (resolvedOrderId ?? '').isEmpty) {
      throw const FormatException('Invalid initiate response from server.');
    }

    return UPaymentInitiateModel(
      orderId: resolvedOrderId!,
      paymentUrl: resolvedPaymentUrl!,
      merchantReferenceId: merchantReferenceId,
      reusedPending: reusedPending,
    );
  }

  static String? _toCleanString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static bool? _toBool(Object? value) {
    if (value == null) return null;
    if (value is bool) return value;
    final text = value.toString().trim().toLowerCase();
    if (text == 'true') return true;
    if (text == 'false') return false;
    return null;
  }
}
