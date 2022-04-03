import 'src/provider_args.dart';

const _defaultSignInScopes = ['https://www.googleapis.com/auth/plus.login'];

class GoogleSignInArgs extends ProviderArgs {
  final String clientId;
  final List<String> scopes;
  final bool immediate;
  final String responseType;

  @override
  final String redirectUri;

  @override
  final host = 'accounts.google.com';

  @override
  final path = '/o/oauth2/auth';

  GoogleSignInArgs({
    required this.clientId,
    required this.redirectUri,
    this.scopes = _defaultSignInScopes,
    this.immediate = false,
    this.responseType = 'token id_token',
  });

  @override
  Map<String, String> buildQueryParameters() {
    return {
      'client_id': clientId,
      'scope': scopes.map((s) => Uri.encodeFull(s)).join(' '),
      'immediate': immediate.toString(),
      'response_type': responseType,
      'redirect_uri': redirectUri,
    };
  }
}
