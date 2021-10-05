import 'package:desktop_webview_auth/src/util.dart';

import 'src/provider_args.dart';

const _responseType = 'token';

class FacebookSignInArgs extends ProviderArgs {
  final String clientId;

  @override
  final String redirectUri;

  @override
  final host = 'www.facebook.com';

  @override
  final path = '/v12.0/dialog/oauth';

  FacebookSignInArgs({
    required this.clientId,
    required this.redirectUri,
  });

  String state = '';

  @override
  Map<String, String> buildQueryParameters() {
    state = generateNonce();

    return {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'state': state,
      'response_type': _responseType,
    };
  }
}
