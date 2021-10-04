import 'package:desktop_webview_auth/src/auth_result.dart';

import 'src/provider_args.dart';

const _host = 'accounts.google.com';
const _path = '/o/oauth2/auth';
const _defaultSignInScope = 'https://www.googleapis.com/auth/plus.login';

class GoogleSignInArgs extends ProviderArgs {
  final String clientId;
  final String scope;
  final bool immediate;
  final String responseType;

  @override
  final String redirectUri;

  GoogleSignInArgs({
    required this.clientId,
    required this.redirectUri,
    this.scope = _defaultSignInScope,
    this.immediate = false,
    this.responseType = 'token',
  });

  @override
  Future<String> buildSignInUri() async {
    final uri = Uri(
      scheme: 'https',
      host: _host,
      path: _path,
      queryParameters: {
        'client_id': clientId,
        'scope': Uri.encodeFull(scope),
        'immediate': immediate.toString(),
        'response_type': responseType,
        'redirect_uri': redirectUri,
      },
    );

    return uri.toString();
  }

  @override
  Future<AuthResult?> authorizeFromCallback(String callbackUrl) async {
    final uri = Uri.parse(callbackUrl.replaceFirst('#', '?'));
    if (uri.queryParameters.containsKey('access_token')) {
      return AuthResult(uri.queryParameters['access_token']!);
    }
  }
}
