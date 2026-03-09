import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// POST /auth/register — Register a new user.
///
/// Creates a user, a personal organization, and returns JWT + refresh token.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.options) {
    return Response(statusCode: 204);
  }

  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final authService = context.read<AuthService>();
  final userRepo = context.read<UserRepository>();
  final orgRepo = context.read<OrganizationRepository>();

  final body = await context.request.json() as Map<String, dynamic>;
  final email = body['email'] as String?;
  final password = body['password'] as String?;
  final name = body['name'] as String?;

  if (email == null || password == null || name == null) {
    return Response.json(
      statusCode: 400,
      body: const ErrorResponse(
        code: 'invalid_request',
        message: 'email, password, and name are required',
      ).toJson(),
    );
  }

  // Check if user already exists
  final existing = await userRepo.findByEmail(email);
  if (existing != null) {
    return Response.json(
      statusCode: 409,
      body: const ErrorResponse(
        code: 'user_exists',
        message: 'A user with this email already exists',
      ).toJson(),
    );
  }

  final passwordHash = authService.hashPassword(password);
  final userId = await userRepo.create(
    email: email,
    displayName: name,
    passwordHash: passwordHash,
  );

  // Create personal organization
  final orgId = await orgRepo.create(name: "$name's Org");
  await orgRepo.addMembership(
    userId: userId,
    organizationId: orgId,
    role: Role.owner,
  );

  final accessToken = authService.createJwt(
    userId: userId,
    email: email,
    displayName: name,
  );
  final refreshToken = await authService.createRefreshToken(userId);

  return Response.json(
    statusCode: 201,
    body: {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': 'Bearer',
      'expires_in': authService.tokenExpiry.inSeconds,
    },
  );
}
