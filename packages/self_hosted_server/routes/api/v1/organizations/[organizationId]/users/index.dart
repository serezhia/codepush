import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// GET  /api/v1/organizations/:organizationId/users — List members.
/// POST /api/v1/organizations/:organizationId/users — Add member by email.
Future<Response> onRequest(
  RequestContext context,
  String organizationId,
) async {
  final orgId = int.tryParse(organizationId);
  if (orgId == null) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: const ErrorResponse(
        code: 'invalid_request',
        message: 'Invalid organizationId',
      ).toJson(),
    );
  }

  return switch (context.request.method) {
    HttpMethod.get => _onGet(context, orgId),
    HttpMethod.post => _onPost(context, orgId),
    _ => Future.value(Response(statusCode: HttpStatus.methodNotAllowed)),
  };
}

Future<Response> _onGet(RequestContext context, int orgId) async {
  final orgRepo = context.read<OrganizationRepository>();
  final users = await orgRepo.getOrganizationUsers(orgId);
  return Response.json(body: users.map((u) => u.toJson()).toList());
}

Future<Response> _onPost(RequestContext context, int orgId) async {
  final body = await context.request.json() as Map<String, dynamic>;
  final email = body['email'] as String?;
  final roleName = body['role'] as String? ?? 'developer';

  if (email == null) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'message': 'email is required'},
    );
  }

  final userRepo = context.read<UserRepository>();
  final user = await userRepo.findByEmail(email);
  if (user == null) {
    return Response.json(
      statusCode: HttpStatus.notFound,
      body: {'message': 'User not found'},
    );
  }

  final role = Role.values.byName(roleName);
  final orgRepo = context.read<OrganizationRepository>();
  await orgRepo.addMembership(
    userId: user['id'] as int,
    organizationId: orgId,
    role: role,
  );

  return Response(statusCode: HttpStatus.created);
}
