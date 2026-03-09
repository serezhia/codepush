/// Authenticated user data injected into request context by auth middleware.
class AuthenticatedUser {
  /// Creates an [AuthenticatedUser].
  const AuthenticatedUser({required this.id, required this.email});

  /// The user's database ID.
  final int id;

  /// The user's email address.
  final String email;
}
