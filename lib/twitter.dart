import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'src/provider_args.dart';

const _host = 'api.twitter.com';
const _path = '/oauth/authenticate';
const _kSignatureMethod = 'HMAC-SHA1';

class TwitterSignInArgs extends ProviderArgs {
  final String apiKey;
  final String apiSecretKey;

  @override
  final String redirectUri;

  TwitterSignInArgs({
    required this.apiKey,
    required this.apiSecretKey,
    required this.redirectUri,
  });

  @override
  Future<String> buildSignInUri() async {
    final reqToken = await getRequestToken();
    return '';
  }

  @override
  String? extractToken(String callbackUrl) {
    // TODO: implement extractToken
    throw UnimplementedError();
  }

  @override
  // TODO: implement redirectUri
  String get redirectUri => throw UnimplementedError();

  Future<String> getRequestToken() async {
    final uri = Uri(
      scheme: 'https',
      host: _host,
      path: '/oauth/request_token',
    );

    final reqBody = {
      'oauth_callback': Uri.encodeFull(redirectUri),
      'oauth_consumer_key': apiKey,
    };

    final res = await http.post(
      uri,
      headers: {
        'accept': 'application/json',
        'Authorization': _buildAuthHeader(
          method: 'POST',
          uri: uri,
          params: reqBody,
        ),
      },
      body: json.encode(reqBody),
    );

    if (res.statusCode == 200) {
      final body = json.decode(res.body);
    } else {
      throw Exception("Couldn't get request token");
    }
  }

  _buildAuthHeader({
    required String method,
    required Uri uri,
    required Map<String, String> params,
  }) {
    final consumerKey = apiKey;
    final nonce = generateNonce();

    final signatire = _sign(
      method: method,
      uri: uri,
      nonce: nonce,
      params: params,
    );
  }

  // https://developer.twitter.com/en/docs/authentication/oauth-1-0a/creating-a-signature
  _sign({
    required String method,
    required Uri uri,
    required String nonce,
    required Map<String, String> params,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final signatureParams = {
      ...params,
      'oauth_consumer_key': apiKey,
      'oauth_nonce': nonce,
      'oauth_signature_method': _kSignatureMethod,
      'oauth_timestamp': timestamp,
    };

    String paramString = '';

    final sortedKeys = signatureParams.keys.toList()..sort();

    for (var key in sortedKeys) {
      if (paramString.isNotEmpty) {
        paramString += '&';
      }

      paramString += key;
      paramString += '=';
      paramString += Uri.encodeFull(signatureParams[key]!.toString());
    }

    String signatureBaseString = '';
  }
}

/// Generates a cryptographically secure random nonce, to be included in a
/// credential request.
String generateNonce([int length = 32]) {
  const charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(length, (_) => charset[random.nextInt(charset.length)])
      .join();
}
