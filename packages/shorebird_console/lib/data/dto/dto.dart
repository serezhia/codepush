import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// Auth token response from login/register endpoints.
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int? ?? 3600,
    );
  }

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
}

/// Collaborator model returned by the server.
class AppCollaborator {
  const AppCollaborator({
    required this.id,
    required this.userId,
    required this.email,
    required this.role,
    this.displayName,
  });

  factory AppCollaborator.fromJson(Map<String, dynamic> json) {
    return AppCollaborator(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      email: json['email'] as String,
      role: AppCollaboratorRole.values.byName(json['role'] as String),
      displayName: json['display_name'] as String?,
    );
  }

  final int id;
  final int userId;
  final String email;
  final AppCollaboratorRole role;
  final String? displayName;
}
