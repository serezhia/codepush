import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// GET /api/v1/apps/:appId/channels — List channels.
/// POST /api/v1/apps/:appId/channels — Create a channel.
Future<Response> onRequest(RequestContext context, String appId) async {
  return switch (context.request.method) {
    HttpMethod.get => _getChannels(context, appId),
    HttpMethod.post => _createChannel(context, appId),
    _ => Future.value(Response(statusCode: 405)),
  };
}

Future<Response> _getChannels(RequestContext context, String appId) async {
  final channelRepo = context.read<ChannelRepository>();
  final channels = await channelRepo.getByAppId(appId);
  return Response.json(body: channels.map((c) => c.toJson()).toList());
}

Future<Response> _createChannel(RequestContext context, String appId) async {
  final channelRepo = context.read<ChannelRepository>();

  final body = await context.request.json() as Map<String, dynamic>;
  final name = body['channel'] as String?;

  if (name == null) {
    return Response.json(
      statusCode: 400,
      body: const ErrorResponse(
        code: 'invalid_request',
        message: 'channel is required',
      ).toJson(),
    );
  }

  final channel = await channelRepo.create(appId: appId, name: name);
  return Response.json(statusCode: 201, body: channel.toJson());
}
