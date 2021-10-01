abstract class ProviderArgs {
  String get redirectUri;
  String buildSignInUri();
  String? extractToken(String callbackUrl);

  Map<String, String> toJson() {
    return {
      'signInUri': buildSignInUri(),
      'redirectUri': redirectUri,
    };
  }
}
