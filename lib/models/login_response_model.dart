import 'user_model.dart';

/// Matches the POST /auth/login success response.
class LoginResponseModel {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresInSeconds;
  final UserModel user;

  const LoginResponseModel({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresInSeconds,
    required this.user,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String? ?? '',
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      expiresInSeconds: json['expiresInSeconds'] as int? ?? 43200,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
