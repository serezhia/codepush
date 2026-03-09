import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// GET /api/v1/apps — List all apps for the current user.
/// POST /api/v1/apps — Create a new app.
Future<Response> onRequest(RequestContext context) async {
  return switch (context.request.method) {
    HttpMethod.get => _getApps(context),
    HttpMethod.post => _createApp(context),
    _ => Future.value(Response(statusCode: 405)),
  };
}

Future<Response> _getApps(RequestContext context) async {
  final user = context.read<AuthenticatedUser>();
  final appRepo = context.read<AppRepository>();

  final apps = await appRepo.getAppsForUser(user.id);

  return Response.json(
    body: GetAppsResponse(apps: apps).toJson(),
  );
}

Future<Response> _createApp(RequestContext context) async {
  final user = context.read<AuthenticatedUser>();
  final appRepo = context.read<AppRepository>();
  final channelRepo = context.read<ChannelRepository>();
  final orgRepo = context.read<OrganizationRepository>();

  final body = await context.request.json() as Map<String, dynamic>;
  final displayName = body['display_name'] as String?;
  final organizationId = body['organization_id'] as int?;

  if (displayName == null || organizationId == null) {
    return Response.json(
      statusCode: 400,
      body: const ErrorResponse(
        code: 'invalid_request',
        message: 'display_name and organization_id are required',
      ).toJson(),
    );
  }

  // Verify user has access to the organization
  final role = await orgRepo.getUserRole(
    userId: user.id,
    organizationId: organizationId,
  );
  if (role == null) {
    return Response.json(
      statusCode: 403,
      body: const ErrorResponse(
        code: 'forbidden',
        message: 'You do not have access to this organization',
      ).toJson(),
    );
  }

  final app = await appRepo.create(
    displayName: displayName,
    organizationId: organizationId,
  );

  // Auto-create "stable" channel
  await channelRepo.create(appId: app.id, name: 'stable');

  return Response.json(statusCode: 201, body: app.toJson());
}
