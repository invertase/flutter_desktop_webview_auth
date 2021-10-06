import 'package:flutter/foundation.dart';

import 'auth_result.dart';

abstract class ProviderArgs {
  String get redirectUri;
  String get host;
  String get path;

  Map<String, String> buildQueryParameters();

  Future<String> buildSignInUri() async {
    final uri = Uri(
      scheme: 'https',
      host: host,
      path: path,
      queryParameters: buildQueryParameters(),
    );

    return SynchronousFuture(uri.toString());
  }

  bool usesFragment = true;

  Future<AuthResult?> authorizeFromCallback(String callbackUrl) {
    final uri = Uri.parse(callbackUrl);
    late Map<String, String> args;

    if (usesFragment) {
      args = Uri.splitQueryString(uri.fragment);
    } else {
      args = uri.queryParameters;
    }

    if (args.containsKey('access_token')) {
      final result = AuthResult(args['access_token']!);
      return SynchronousFuture(result);
    }

    throw Exception('No access token found');
  }

  Future<Map<String, String>> toJson() async {
    return {
      'signInUri': await buildSignInUri(),
      'redirectUri': redirectUri,
    };
  }
}
