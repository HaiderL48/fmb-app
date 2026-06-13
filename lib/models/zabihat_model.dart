/// Matches the `zabihat_offerings` table and the `Zabihat` interface from mockData.ts
class ZabihatModel {
  final String id;
  final String title;
  final String? code;
  final String? description;
  final double priceKd;
  final int capacity; // maxUnits
  final int unitsSold;
  final bool isEnabled;
  final int sortOrder;

  const ZabihatModel({
    required this.id,
    required this.title,
    this.code,
    this.description,
    required this.priceKd,
    required this.capacity,
    this.unitsSold = 0,
    this.isEnabled = true,
    this.sortOrder = 0,
  });

  /// Computed: units still available
  int get available => capacity - unitsSold;

  factory ZabihatModel.fromJson(Map<String, dynamic> json) {
    final capacity = json['capacity'] as int? ?? json['maxUnits'] as int? ?? 0;
    final unitsSold =
        json['unitsSold'] as int? ??
        (capacity - (json['availableUnits'] as int? ?? capacity));

    return ZabihatModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? json['name'] as String? ?? '',
      code: json['code'] as String?,
      description: json['description'] as String?,
      priceKd: (json['priceKd'] as num? ?? json['pricePerUnit'] as num? ?? 0)
          .toDouble(),
      capacity: capacity,
      unitsSold: unitsSold,
      isEnabled: json['isEnabled'] as bool? ?? json['enabled'] as bool? ?? true,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'code': code,
    'description': description,
    'priceKd': priceKd,
    'capacity': capacity,
    'unitsSold': unitsSold,
    'available': available,
    'isEnabled': isEnabled,
    'sortOrder': sortOrder,
  };

  ZabihatModel copyWith({
    String? id,
    String? title,
    String? code,
    String? description,
    double? priceKd,
    int? capacity,
    int? unitsSold,
    bool? isEnabled,
    int? sortOrder,
  }) {
    return ZabihatModel(
      id: id ?? this.id,
      title: title ?? this.title,
      code: code ?? this.code,
      description: description ?? this.description,
      priceKd: priceKd ?? this.priceKd,
      capacity: capacity ?? this.capacity,
      unitsSold: unitsSold ?? this.unitsSold,
      isEnabled: isEnabled ?? this.isEnabled,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
