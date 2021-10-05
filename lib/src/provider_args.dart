import 'auth_result.dart';

abstract class ProviderArgs {
  String get redirectUri;
  Future<String> buildSignInUri();
  Future<AuthResult?> authorizeFromCallback(String callbackUrl);

  Future<Map<String, String>> toJson() async {
    return {
      'signInUri': await buildSignInUri(),
      'redirectUri': redirectUri,
    };
  }
}
