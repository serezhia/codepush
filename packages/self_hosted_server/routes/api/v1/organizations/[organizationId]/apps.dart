import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// GET /api/v1/organizations/:organizationId/apps — List apps for an organization.
Future<Response> onRequest(
  RequestContext context,
  String organizationId,
) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final orgId = int.tryParse(organizationId);
  if (orgId == null) {
    return Response.json(
      statusCode: 400,
      body: const ErrorResponse(
        code: 'invalid_request',
        message: 'Invalid organizationId',
      ).toJson(),
    );
  }

  final appRepo = context.read<AppRepository>();
  final apps = await appRepo.getAppsByOrganization(orgId);

  return Response.json(
    body: GetOrganizationAppsResponse(apps: apps).toJson(),
  );
}
