/// Linked distributor row returned on public user objects from the API.
class UserDistributorRef {
  const UserDistributorRef({
    required this.id,
    required this.name,
    required this.mobileNumber,
  });

  final String id;
  final String name;
  final String mobileNumber;

  factory UserDistributorRef.fromJson(Map<String, dynamic> json) {
    return UserDistributorRef(
      id: json['id'] as String? ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      mobileNumber: (json['mobileNumber'] as String? ?? json['mobile_number'] as String?)
              ?.trim() ??
          '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mobileNumber': mobileNumber,
      };
}

/// Matches the `users` table and the `User` interface from mockData.ts
class UserModel {
  final String id;
  final String itsNumber;
  final String password;
  final String fullName;
  final String address;
  final String contactPhone;
  final String email;
  final String? thaliNumber;
  final String? sabilNumber;
  final String? packageId;
  final bool isFirstLogin;
  final String userType; // "ADMIN" | "APP_USER"
  final bool isActive;
  final UserDistributorRef? distributor;
  final double? distributorPriceKd;

  const UserModel({
    required this.id,
    required this.itsNumber,
    this.password = '',
    required this.fullName,
    this.address = '',
    this.contactPhone = '',
    required this.email,
    this.thaliNumber,
    this.sabilNumber,
    this.packageId,
    this.isFirstLogin = false,
    this.userType = 'APP_USER',
    this.isActive = true,
    this.distributor,
    this.distributorPriceKd,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    UserDistributorRef? distributor;
    final rawDist = json['distributor'];
    if (rawDist is Map<String, dynamic>) {
      final d = UserDistributorRef.fromJson(rawDist);
      if (d.id.isNotEmpty) {
        distributor = d;
      }
    }

    double? distributorPriceKd;
    final rawPrice = json['distributorPriceKd'] ?? json['distributor_price_kd'];
    if (rawPrice is num) {
      distributorPriceKd = rawPrice.toDouble();
    } else if (rawPrice != null) {
      distributorPriceKd = double.tryParse(rawPrice.toString());
    }

    return UserModel(
      id: json['id'] as String,
      itsNumber: json['itsNumber'] as String,
      password: json['password'] as String? ?? '',
      fullName: json['fullName'] as String? ?? json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      contactPhone:
          json['contactPhone'] as String? ?? json['contact'] as String? ?? '',
      email: json['email'] as String,
      thaliNumber: json['thaliNumber'] as String?,
      sabilNumber: json['sabilNumber'] as String?,
      packageId: json['packageId'] as String?,
      isFirstLogin: json['isFirstLogin'] as bool? ?? false,
      userType: json['userType'] as String? ?? 'APP_USER',
      isActive: json['isActive'] as bool? ?? true,
      distributor: distributor,
      distributorPriceKd: distributorPriceKd,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'itsNumber': itsNumber,
    'password': password,
    'fullName': fullName,
    'address': address,
    'contactPhone': contactPhone,
    'email': email,
    'thaliNumber': thaliNumber,
    'sabilNumber': sabilNumber,
    'packageId': packageId,
    'isFirstLogin': isFirstLogin,
    'userType': userType,
    'isActive': isActive,
    if (distributor != null) 'distributor': distributor!.toJson(),
    if (distributorPriceKd != null) 'distributorPriceKd': distributorPriceKd,
  };

  UserModel copyWith({
    String? id,
    String? itsNumber,
    String? password,
    String? fullName,
    String? address,
    String? contactPhone,
    String? email,
    String? thaliNumber,
    String? sabilNumber,
    String? packageId,
    bool? isFirstLogin,
    String? userType,
    bool? isActive,
    UserDistributorRef? distributor,
    double? distributorPriceKd,
  }) {
    return UserModel(
      id: id ?? this.id,
      itsNumber: itsNumber ?? this.itsNumber,
      password: password ?? this.password,
      fullName: fullName ?? this.fullName,
      address: address ?? this.address,
      contactPhone: contactPhone ?? this.contactPhone,
      email: email ?? this.email,
      thaliNumber: thaliNumber ?? this.thaliNumber,
      sabilNumber: sabilNumber ?? this.sabilNumber,
      packageId: packageId ?? this.packageId,
      isFirstLogin: isFirstLogin ?? this.isFirstLogin,
      userType: userType ?? this.userType,
      isActive: isActive ?? this.isActive,
      distributor: distributor ?? this.distributor,
      distributorPriceKd: distributorPriceKd ?? this.distributorPriceKd,
    );
  }
}
