class AuthResult {
  final String accessToken;
  final String? tokenSecret;

  AuthResult(this.accessToken, [this.tokenSecret]);
}
