import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// POST /api/v1/users — Create a new user (used by CLI after first login).
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final user = context.read<AuthenticatedUser>();
  final userRepo = context.read<UserRepository>();

  final body = await context.request.json() as Map<String, dynamic>;
  final name = body['name'] as String?;

  // User already exists (created during registration), update display name
  final existing = await userRepo.findById(user.id);
  if (existing != null) {
    return Response.json(
      body: PrivateUser(
        id: existing['id'] as int,
        email: existing['email'] as String,
        displayName: name ?? existing['display_name'] as String?,
        hasActiveSubscription: true,
        jwtIssuer:
            context.read<Dependencies>().config.authIssuer ??
            context.read<Dependencies>().config.serverUrl,
      ).toJson(),
    );
  }

  return Response.json(
    statusCode: 404,
    body: const ErrorResponse(
      code: 'not_found',
      message: 'User not found',
    ).toJson(),
  );
}
