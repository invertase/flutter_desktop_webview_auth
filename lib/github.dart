import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;

import 'src/auth_result.dart';
import 'src/provider_args.dart';
import 'src/util.dart';

class GitHubSignInArgs extends ProviderArgs {
  final String clientId;

  final String clientSecret;

  @override
  final String redirectUri;

  @override
  final host = 'github.com';

  @override
  final path = '/login/oauth/authorize';

  final _accessTokenPath = '/login/oauth/access_token';

  /// Suggests a specific account to use for signing in and authorizing the app.
  final String? login;

  /// Allowed scopes of this app.
  ///
  /// For full list of scopes,
  /// see https://docs.github.com/en/developers/apps/building-oauth-apps/scopes-for-oauth-apps
  final String scope;

  /// Whether or not unauthenticated users will be offered an option to sign up
  /// for GitHub during the OAuth flow.
  final bool? allowSignup;

  GitHubSignInArgs({
    required this.clientId,
    required this.clientSecret,
    required this.redirectUri,
    this.login,
    this.scope = 'user',
    this.allowSignup,
  });

  String state = '';

  @override
  Map<String, String> buildQueryParameters() {
    state = generateNonce();

    return {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'state': state,
      'allow_signup': '${allowSignup ?? false}',
      'scope': scope,
    };
  }

  @override
  Future<AuthResult?> authorizeFromCallback(String callbackUrl) async {
    final parsed = Uri.parse(callbackUrl);
    final code = parsed.queryParameters['code'] as String;
    final state = parsed.queryParameters['state'] as String;

    log(code);
    log(state);

    if (this.state == state) {
      final res = await _post(
        _accessTokenPath,
        {
          'client_id': clientId,
          'client_secret': clientSecret,
          'code': code,
          'redirect_uri': redirectUri,
        },
      );

      if (res == null) throw Exception("Couldn't authroize");

      final decodedRes = json.decode(res);

      return AuthResult(
        accessToken: decodedRes['access_token'],
      );
    } else {
      throw Exception("Couldn't authroize, the state recieved by GitHub "
          "doesn't match state used to authorize.");
    }
  }

  Future<String?> _post(String path, Map<String, String> params) async {
    final uri = Uri(
      scheme: 'https',
      host: host,
      path: path,
    );

    try {
      final res = await http.post(
        uri,
        headers: {"Accept": "application/json"},
        body: params,
      );

      if (res.statusCode == 200) {
        return res.body;
      } else {
        throw Exception('HttpCode: ${res.statusCode}, Body: ${res.body}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
