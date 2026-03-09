import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// POST /api/v1/apps/:appId/patches/promote — Promote a patch to a channel.
Future<Response> onRequest(RequestContext context, String appId) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final channelRepo = context.read<ChannelRepository>();

  final body = await context.request.json() as Map<String, dynamic>;
  final patchId = body['patch_id'] as int?;
  final channelId = body['channel_id'] as int?;

  if (patchId == null || channelId == null) {
    return Response.json(
      statusCode: 400,
      body: const ErrorResponse(
        code: 'invalid_request',
        message: 'patch_id and channel_id are required',
      ).toJson(),
    );
  }

  await channelRepo.promotePatch(patchId: patchId, channelId: channelId);

  return Response(statusCode: 204);
}
