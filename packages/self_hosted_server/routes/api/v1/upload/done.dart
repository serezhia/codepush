import 'package:dart_frog/dart_frog.dart';

/// POST /api/v1/upload/done
///
/// No-op endpoint. The Shorebird CLI performs a two-step artifact upload:
/// 1. POST multipart to the artifact endpoint (server stores the file)
/// 2. POST multipart to the URL returned in the response (this endpoint)
///
/// Since the file is already stored in step 1, this endpoint simply returns
/// 200 OK to satisfy the CLI's upload confirmation step.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }
  await context.request.bytes().drain<void>();
  return Response();
}
