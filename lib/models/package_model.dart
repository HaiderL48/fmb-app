/// Matches the `subscription_packages` table and the `Package` interface from mockData.ts
enum PackageTier { basic, premium, family }

extension PackageTierExtension on PackageTier {
  String get label {
    switch (this) {
      case PackageTier.basic:
        return 'Basic';
      case PackageTier.premium:
        return 'Premium';
      case PackageTier.family:
        return 'Family';
    }
  }

  static PackageTier fromString(String value) {
    switch (value.toLowerCase()) {
      case 'premium':
        return PackageTier.premium;
      case 'family':
        return PackageTier.family;
      default:
        return PackageTier.basic;
    }
  }
}

class PackageModel {
  final String id;
  final String name;
  final PackageTier tier;
  final double priceKd;
  final List<String> features;
  final String validity;
  final List<double> installmentOptions;
  final bool isActive;
  final int sortOrder;

  const PackageModel({
    required this.id,
    required this.name,
    required this.tier,
    required this.priceKd,
    required this.features,
    required this.validity,
    required this.installmentOptions,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory PackageModel.fromJson(Map<String, dynamic> json) {
    return PackageModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['title'] as String? ?? '',
      tier: PackageTierExtension.fromString(
        json['type'] as String? ?? json['tier'] as String? ?? '',
      ),
      priceKd: (json['price'] as num? ?? json['priceKd'] as num? ?? 0)
          .toDouble(),
      features: List<String>.from(json['features'] as List? ?? []),
      validity: json['validity'] as String? ?? '',
      installmentOptions: List<double>.from(
        (json['installmentOptions'] as List? ??
                json['installmentsKd'] as List? ??
                [])
            .map((e) => (e as num).toDouble()),
      ),
      isActive: json['isActive'] as bool? ?? true,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tier': tier.label,
    'priceKd': priceKd,
    'features': features,
    'validity': validity,
    'installmentOptions': installmentOptions,
    'isActive': isActive,
    'sortOrder': sortOrder,
  };

  PackageModel copyWith({
    String? id,
    String? name,
    PackageTier? tier,
    double? priceKd,
    List<String>? features,
    String? validity,
    List<double>? installmentOptions,
    bool? isActive,
    int? sortOrder,
  }) {
    return PackageModel(
      id: id ?? this.id,
      name: name ?? this.name,
      tier: tier ?? this.tier,
      priceKd: priceKd ?? this.priceKd,
      features: features ?? this.features,
      validity: validity ?? this.validity,
      installmentOptions: installmentOptions ?? this.installmentOptions,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
