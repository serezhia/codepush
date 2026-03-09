import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// /auth/login
///
/// GET  — Renders HTML login form for CLI loopback OAuth flow.
///        Expects `?continue=<callback_url>` query parameter.
/// POST — Authenticates with email + password.
///        If `continue` is provided, redirects to callback with auth code.
///        Otherwise returns JWT + refresh token as JSON (console flow).
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.options) {
    return Response(statusCode: 204);
  }

  if (context.request.method == HttpMethod.get) {
    return _handleGet(context);
  }

  if (context.request.method == HttpMethod.post) {
    return _handlePost(context);
  }

  return Response(statusCode: 405);
}

/// GET /auth/login?continue=<url> — Render HTML login page for CLI.
Response _handleGet(RequestContext context) {
  final continueUrl = context.request.uri.queryParameters['continue'];
  return Response(
    headers: {'Content-Type': 'text/html; charset=utf-8'},
    body: _loginPageHtml(continueUrl: continueUrl),
  );
}

/// POST /auth/login — Authenticate and respond based on flow:
/// - With `continue` param: CLI flow → redirect with auth code
/// - Without: Console flow → return JSON tokens
Future<Response> _handlePost(RequestContext context) async {
  final authService = context.read<AuthService>();
  final userRepo = context.read<UserRepository>();

  // Parse body — support both JSON and form-encoded.
  final contentType = context.request.headers['content-type'] ?? '';
  Map<String, dynamic> body;
  if (contentType.contains('application/x-www-form-urlencoded')) {
    final raw = await context.request.body();
    body = Uri.splitQueryString(raw);
  } else {
    body = await context.request.json() as Map<String, dynamic>;
  }

  final email = body['email'] as String?;
  final password = body['password'] as String?;
  final continueUrl = body['continue'] as String?;

  if (email == null || password == null) {
    if (continueUrl != null) {
      return Response(
        headers: {'Content-Type': 'text/html; charset=utf-8'},
        body: _loginPageHtml(
          continueUrl: continueUrl,
          error: 'Email and password are required.',
        ),
      );
    }
    return Response.json(
      statusCode: 400,
      body: const ErrorResponse(
        code: 'invalid_request',
        message: 'email and password are required',
      ).toJson(),
    );
  }

  final user = await userRepo.findByEmail(email);
  if (user == null ||
      !authService.verifyPassword(
        password,
        user['password_hash'] as String,
      )) {
    if (continueUrl != null) {
      return Response(
        headers: {'Content-Type': 'text/html; charset=utf-8'},
        body: _loginPageHtml(
          continueUrl: continueUrl,
          error: 'Invalid email or password.',
          email: email,
        ),
      );
    }
    return Response.json(
      statusCode: 401,
      body: const ErrorResponse(
        code: 'invalid_credentials',
        message: 'Invalid email or password',
      ).toJson(),
    );
  }

  final userId = user['id'] as int;

  // CLI loopback flow: create auth code and redirect to callback.
  if (continueUrl != null) {
    final code = await authService.createAuthCode(userId);
    final callbackUri = Uri.parse(continueUrl).replace(
      queryParameters: {'code': code},
    );
    return Response(
      statusCode: 302,
      headers: {'Location': callbackUri.toString()},
    );
  }

  // Console flow: return tokens as JSON.
  final accessToken = authService.createJwt(
    userId: userId,
    email: email,
    displayName: user['display_name'] as String?,
  );
  final refreshToken = await authService.createRefreshToken(userId);

  return Response.json(
    body: {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': 'Bearer',
      'expires_in': authService.tokenExpiry.inSeconds,
    },
  );
}

String _loginPageHtml({
  String? continueUrl,
  String? error,
  String? email,
}) {
  final errorHtml = error != null
      ? '<div style="color:#d32f2f;background:#fdecea;padding:12px;border-radius:8px;margin-bottom:16px">$error</div>'
      : '';
  final continueField = continueUrl != null
      ? '<input type="hidden" name="continue" '
            'value="$continueUrl" />'
      : '';
  final emailValue = email ?? '';

  return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Shorebird Login</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto,
        sans-serif;
      background: #0f172a; color: #e2e8f0;
      display: flex; align-items: center; justify-content: center;
      min-height: 100vh;
    }
    .card {
      background: #1e293b; border-radius: 16px; padding: 40px;
      width: 100%; max-width: 400px; box-shadow: 0 8px 32px #0004;
    }
    h1 { text-align: center; margin-bottom: 8px; font-size: 24px; }
    .subtitle {
      text-align: center; color: #94a3b8; margin-bottom: 24px;
      font-size: 14px;
    }
    label { display: block; margin-bottom: 4px; font-size: 14px; }
    input[type=email], input[type=password] {
      width: 100%; padding: 10px 14px; border-radius: 8px;
      border: 1px solid #334155; background: #0f172a; color: #e2e8f0;
      font-size: 16px; margin-bottom: 16px; outline: none;
    }
    input:focus { border-color: #3b82f6; }
    button {
      width: 100%; padding: 12px; border: none; border-radius: 8px;
      background: #3b82f6; color: #fff; font-size: 16px;
      font-weight: 600; cursor: pointer;
    }
    button:hover { background: #2563eb; }
  </style>
</head>
<body>
  <div class="card">
    <h1>&#x1F426; Shorebird</h1>
    <p class="subtitle">Sign in to continue to the CLI</p>
    $errorHtml
    <form method="POST">
      $continueField
      <label for="email">Email</label>
      <input id="email" name="email" type="email" required
        value="$emailValue" autofocus>
      <label for="password">Password</label>
      <input id="password" name="password" type="password" required>
      <button type="submit">Sign In</button>
    </form>
  </div>
</body>
</html>''';
}
