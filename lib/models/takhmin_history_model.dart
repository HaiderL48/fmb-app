class TakhminHistoryModel {
  final String id;
  final int misriYear;
  final double takhminAmountKd;
  final bool completed;
  final DateTime? updatedAt;

  const TakhminHistoryModel({
    required this.id,
    required this.misriYear,
    required this.takhminAmountKd,
    required this.completed,
    this.updatedAt,
  });

  factory TakhminHistoryModel.fromJson(Map<String, dynamic> json) {
    final updatedAtRaw =
        json['updatedAt'] as String? ??
        json['createdAt'] as String? ??
        json['date'] as String?;

    return TakhminHistoryModel(
      id: (json['id'] ?? '${json['misriYear'] ?? json['misri_year'] ?? ''}-${json['takhminAmountKd'] ?? json['takhmin_amount_kd'] ?? ''}')
          .toString(),
      misriYear:
          (json['misriYear'] as num? ??
                  json['misri_year'] as num? ??
                  json['year'] as num? ??
                  DateTime.now().year)
              .toInt(),
      takhminAmountKd: (json['takhminAmountKd'] as num? ??
              json['takhmin_amount_kd'] as num? ??
              json['amountKd'] as num? ??
              json['amount_kd'] as num? ??
              json['amount'] as num? ??
              0)
          .toDouble(),
      completed: (json['completed'] as bool?) ??
          ((json['status'] as String?)?.toLowerCase() == 'completed'),
      updatedAt: updatedAtRaw == null ? null : DateTime.tryParse(updatedAtRaw),
    );
  }
}
