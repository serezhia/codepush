import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';

Future<Response> onRequest(RequestContext context, String appId) async {
  return switch (context.request.method) {
    HttpMethod.get => _onGet(context, appId),
    HttpMethod.post => _onPost(context, appId),
    _ => Future.value(Response(statusCode: HttpStatus.methodNotAllowed)),
  };
}

Future<Response> _onGet(RequestContext context, String appId) async {
  final appRepo = context.read<AppRepository>();
  final collaborators = await appRepo.getCollaborators(appId);
  return Response.json(body: collaborators);
}

Future<Response> _onPost(RequestContext context, String appId) async {
  final body = await context.request.json() as Map<String, dynamic>;
  final email = body['email'] as String?;
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

  final appRepo = context.read<AppRepository>();
  await appRepo.addCollaborator(
    appId: appId,
    userId: user['id'] as int,
    role: 'developer',
  );

  return Response(statusCode: HttpStatus.created);
}
