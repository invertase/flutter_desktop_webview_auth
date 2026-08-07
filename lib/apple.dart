import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'src/provider_args.dart';
import 'src/util.dart';

const _defaultSignInScope = '';

/// @see https://developer.apple.com/documentation/sign_in_with_apple/request_an_authorization_to_the_sign_in_with_apple_server
///
/// [scope] The amount of user information requested from Apple.
///   Valid values are name and email. You can request one, both, or none.
///   Use space separation and percent-encoding for multiple scopes;
///   for example, "scope=name%20email".
///
/// [responseType] The type of response requested. Valid values are
///   code and id_token. You can request only code, or both code and id_token.
///   Requesting only id_token is unsupported. When requesting id_token,
///   [responseMode] must be either fragment or form_post.
///
/// [responseMode] The type of response mode expected. Valid values are query,
///   fragment, and form_post.
///   If you requested any [scope]s, the value must be form_post.
///   Note! Firebase auth support only fragment mode, so [scope] must be empty
///
/// [nonce] Auto generated, but need for using in
///   Firebase AppleAuthProvider.credentialWithIDToken, see example below.
///
/// ###Example of using with Firebase Auth:
///
///     final args = AppleSignInArgs(
///       clientId: "my-services-id", //Services ID used as the web application identifier
///       redirectUri: "https://your-project.firebaseapp.com/__/auth/handler",
///     );
///
///     final result = await DesktopWebviewAuth.signIn(args);
///     if (result == null || result.idToken == null) {
///       throw Exception("Authorize process terminated");
///     }
///
///     final credential = OAuthProvider("apple.com").credential(idToken: result.idToken!, rawNonce: args.nonce);
///     FirebaseAuth.instance.signInWithCredential(credential);
///
class AppleSignInArgs extends ProviderArgs {
  final String clientId;
  final String scope;
  final String responseType;
  final String responseMode;
  final String nonce;

  @override
  final String redirectUri;

  @override
  final host = 'appleid.apple.com';

  @override
  final path = '/auth/authorize';

  AppleSignInArgs({
    required this.clientId,
    required this.redirectUri,
    this.scope = _defaultSignInScope,
    this.responseType = 'code id_token',
    this.responseMode = 'fragment',
    String? nonce,
  }) : nonce = nonce ?? generateNonce();

  @override
  Map<String, String> buildQueryParameters() {
    return {
      'client_id': clientId,
      'scope': scope,
      'response_type': responseType,
      'response_mode': responseMode,
      'redirect_uri': redirectUri,
      'nonce': sha256.convert(utf8.encode(nonce)).toString(),
    };
  }
}
