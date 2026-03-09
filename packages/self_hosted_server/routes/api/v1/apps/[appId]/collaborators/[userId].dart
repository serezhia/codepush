import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';

Future<Response> onRequest(
  RequestContext context,
  String appId,
  String userId,
) async {
  return switch (context.request.method) {
    HttpMethod.patch => _onPatch(context, appId, userId),
    HttpMethod.delete => _onDelete(context, appId, userId),
    _ => Future.value(Response(statusCode: HttpStatus.methodNotAllowed)),
  };
}

Future<Response> _onPatch(
  RequestContext context,
  String appId,
  String userId,
) async {
  final body = await context.request.json() as Map<String, dynamic>;
  final role = body['role'] as String?;
  if (role == null) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'message': 'role is required'},
    );
  }

  final appRepo = context.read<AppRepository>();
  await appRepo.updateCollaboratorRole(
    appId: appId,
    userId: int.parse(userId),
    role: role,
  );

  return Response(statusCode: HttpStatus.noContent);
}

Future<Response> _onDelete(
  RequestContext context,
  String appId,
  String userId,
) async {
  final appRepo = context.read<AppRepository>();
  await appRepo.removeCollaborator(
    appId: appId,
    userId: int.parse(userId),
  );

  return Response(statusCode: HttpStatus.noContent);
}
