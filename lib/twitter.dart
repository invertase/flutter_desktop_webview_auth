import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'src/provider_args.dart';

const _host = 'api.twitter.com';
const _authPath = '/oauth/authenticate';
const _requestTokenPath = '/oauth/access_token';

const _kSignatureMethod = 'HMAC-SHA1';
const _kOAuthVersion = '1.0';

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
    final token = await getRequestToken();
    return 'https://api.twitter.com/oauth/authorize?oauth_token=$token';
  }

  @override
  String? extractToken(String callbackUrl) {
    print(callbackUrl);
  }

  Future<String> getRequestToken() async {
    final uri = Uri(
      scheme: 'https',
      host: _host,
      path: '/oauth/request_token',
    );

    final reqBody = {
      'oauth_callback': Uri.encodeFull(redirectUri),
    };

    try {
      final authorization = _buildAuthHeader(
        method: 'POST',
        uri: uri,
        params: reqBody,
      );

      final res = await http.post(
        uri,
        headers: {
          'Authorization': authorization,
        },
      );

      if (res.statusCode == 200) {
        final body = Uri.splitQueryString(res.body);

        if (body.containsKey('oauth_token')) {
          return body['oauth_token'] as String;
        } else {
          throw Exception("Couldn't get request token");
        }
      } else {
        throw Exception("Couldn't get request token");
      }
    } catch (e) {
      rethrow;
    }
  }

  String _buildAuthHeader({
    required String method,
    required Uri uri,
    required Map<String, String> params,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final nonce = generateNonce();

    final signature = _createSignature(
      method: method,
      uri: uri,
      timestamp: timestamp,
      nonce: nonce,
      params: params,
    );

    final paramsClone = Map<String, dynamic>.from(params);
    final authComponents = [
      'OAuth oauth_consumer_key="$apiKey"',
      'oauth_nonce="$nonce"',
      'oauth_signature="$signature"',
      'oauth_signature_method="$_kSignatureMethod"',
      'oauth_timestamp="$timestamp"',
      'oauth_version="$_kOAuthVersion"',
      for (var key in paramsClone.keys)
        '$key="${Uri.encodeComponent(paramsClone[key])}"'
    ];

    authComponents.sort();

    return authComponents.join(', ');
  }

  // https://developer.twitter.com/en/docs/authentication/oauth-1-0a/creating-a-signature
  String _createSignature({
    required String method,
    required Uri uri,
    required int timestamp,
    required String nonce,
    required Map<String, String> params,
    String requestToken = '',
  }) {
    final signatureParams = {
      ...params,
      'oauth_consumer_key': apiKey,
      'oauth_nonce': nonce,
      'oauth_signature_method': _kSignatureMethod,
      'oauth_timestamp': timestamp,
      'oauth_version': _kOAuthVersion,
    };

    String paramString = '';

    final sortedKeys = signatureParams.keys.toList()..sort();

    for (var key in sortedKeys) {
      if (paramString.isNotEmpty) {
        paramString += '&';
      }

      paramString += key;
      paramString += '=';
      paramString += Uri.encodeComponent(signatureParams[key]!.toString());
    }

    final encodedUri = Uri.encodeComponent(uri.toString());
    final encodedParamString = Uri.encodeComponent(paramString);

    final signatureBaseString = '${method.toUpperCase()}'
        '&$encodedUri'
        '&$encodedParamString';

    final signingKey = '${Uri.encodeComponent(apiSecretKey)}&$requestToken';

    final hmacSha1 = Hmac(sha1, signingKey.codeUnits);
    final digest = hmacSha1.convert(signatureBaseString.codeUnits);
    final signature = base64.encode(digest.bytes);

    return Uri.encodeComponent(signature);
  }
}

/// Generates a cryptographically secure random nonce, to be included in a
/// credential request.
String generateNonce([int length = 32]) {
  const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz';
  final random = Random.secure();

  return List.generate(
    length,
    (_) => chars[random.nextInt(chars.length)],
  ).join();
}
