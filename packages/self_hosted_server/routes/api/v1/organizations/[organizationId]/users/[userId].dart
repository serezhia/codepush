import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// PATCH  — Update member role.
/// DELETE — Remove member from organization.
Future<Response> onRequest(
  RequestContext context,
  String organizationId,
  String userId,
) async {
  final orgId = int.tryParse(organizationId);
  final uid = int.tryParse(userId);
  if (orgId == null || uid == null) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'message': 'Invalid organizationId or userId'},
    );
  }

  return switch (context.request.method) {
    HttpMethod.patch => _onPatch(context, orgId, uid),
    HttpMethod.delete => _onDelete(context, orgId, uid),
    _ => Future.value(Response(statusCode: HttpStatus.methodNotAllowed)),
  };
}

Future<Response> _onPatch(
  RequestContext context,
  int orgId,
  int userId,
) async {
  final body = await context.request.json() as Map<String, dynamic>;
  final roleName = body['role'] as String?;
  if (roleName == null) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'message': 'role is required'},
    );
  }

  final role = Role.values.byName(roleName);
  final orgRepo = context.read<OrganizationRepository>();
  await orgRepo.addMembership(
    userId: userId,
    organizationId: orgId,
    role: role,
  );

  return Response(statusCode: HttpStatus.noContent);
}

Future<Response> _onDelete(
  RequestContext context,
  int orgId,
  int userId,
) async {
  final orgRepo = context.read<OrganizationRepository>();
  await orgRepo.removeMembership(userId: userId, organizationId: orgId);
  return Response(statusCode: HttpStatus.noContent);
}
