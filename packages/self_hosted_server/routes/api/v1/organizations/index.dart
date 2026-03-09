import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// GET /api/v1/organizations — List organizations for the current user.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final user = context.read<AuthenticatedUser>();
  final orgRepo = context.read<OrganizationRepository>();

  final orgs = await orgRepo.getUserOrganizations(user.id);

  return Response.json(
    body: GetOrganizationsResponse(organizations: orgs).toJson(),
  );
}
