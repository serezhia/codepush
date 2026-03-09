import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// DELETE /api/v1/apps/:appId — Delete an app.
Future<Response> onRequest(RequestContext context, String appId) async {
  if (context.request.method != HttpMethod.delete) {
    return Response(statusCode: 405);
  }

  final appRepo = context.read<AppRepository>();

  final app = await appRepo.findById(appId);
  if (app == null) {
    return Response.json(
      statusCode: 404,
      body: const ErrorResponse(
        code: 'not_found',
        message: 'App not found',
      ).toJson(),
    );
  }

  await appRepo.delete(appId);

  return Response(statusCode: 204);
}
