class AuthResult {
  final String? accessToken;
  final String? idToken;
  final String? tokenSecret;

  const AuthResult({
    this.accessToken,
    this.idToken,
    this.tokenSecret,
  });

  @override
  String toString() {
    return 'AuthResult(idToken: $idToken, accessToken: $accessToken, tokenSecret: $tokenSecret)';
  }
}
