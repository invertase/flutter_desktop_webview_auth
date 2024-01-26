import 'src/provider_args.dart';
import 'src/util.dart';

const _defaultSignInScope = 'https://www.googleapis.com/auth/plus.login';

class GoogleSignInArgs extends ProviderArgs {
  final String clientId;
  final String scope;
  final bool immediate;
  final String responseType;

  @override
  final String redirectUri;

  @override
  final host = 'accounts.google.com';

  @override
  final path = '/o/oauth2/v2/auth';

  GoogleSignInArgs({
    required this.clientId,
    required this.redirectUri,
    this.scope = _defaultSignInScope,
    this.immediate = false,
    this.responseType = 'token id_token',
  });

  @override
  Map<String, String> buildQueryParameters() {
    return {
      'client_id': clientId,
      'scope': scope,
      'immediate': immediate.toString(),
      'response_type': responseType,
      'redirect_uri': redirectUri,
      'nonce': generateNonce()
    };
  }
}
