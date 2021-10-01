abstract class ProviderArgs {
  String get redirectUri;
  Future<String> buildSignInUri();
  String? extractToken(String callbackUrl);

  Future<Map<String, String>> toJson() async {
    return {
      'signInUri': await buildSignInUri(),
      'redirectUri': redirectUri,
    };
  }
}
