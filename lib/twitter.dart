import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:desktop_webview_auth/src/auth_result.dart';
import 'package:http/http.dart' as http;
import 'src/provider_args.dart';
import 'src/util.dart';

const _requestTokenPath = '/oauth/request_token';
const _accessTokenPath = '/oauth/access_token';

const _kSignatureMethod = 'HMAC-SHA1';
const _kOAuthVersion = '1.0';

class TwitterSignInArgs extends ProviderArgs {
  final String apiKey;
  final String apiSecretKey;

  @override
  final String redirectUri;

  @override
  final host = 'api.twitter.com';

  @override
  final path = '/oauth/authorize';

  TwitterSignInArgs({
    required this.apiKey,
    required this.apiSecretKey,
    required this.redirectUri,
  });

  late String token;

  @override
  Map<String, String> buildQueryParameters() {
    return {'oauth_token': token};
  }

  @override
  Future<String> buildSignInUri() async {
    token = await getRequestToken();
    return super.buildSignInUri();
  }

  @override
  Future<AuthResult?> authorizeFromCallback(String callbackUrl) async {
    final parsed = Uri.parse(callbackUrl);
    final oauthToken = parsed.queryParameters['oauth_token'] as String;
    final oauthVerifier = parsed.queryParameters['oauth_verifier'] as String;

    final res = await _post(_accessTokenPath, {
      'oauth_token': oauthToken,
      'oauth_verifier': oauthVerifier,
    });

    if (res == null) throw Exception("Couldn't authroize");

    final decodedRes = Uri.splitQueryString(res);

    return AuthResult(
      accessToken: decodedRes['oauth_token'],
      tokenSecret: decodedRes['oauth_token_secret'],
    );
  }

  Future<String> getRequestToken() async {
    try {
      final res = await _post(_requestTokenPath, {
        'oauth_callback': Uri.encodeFull(redirectUri),
      });

      if (res == null) throw Exception();

      final body = Uri.splitQueryString(res);

      if (body.containsKey('oauth_token')) {
        return body['oauth_token'] as String;
      } else {
        throw Exception();
      }
    } on Exception catch (_) {
      throw Exception("Couldn't get request token");
    }
  }

  Future<String?> _post(String path, Map<String, String> params) async {
    final uri = Uri(
      scheme: 'https',
      host: host,
      path: path,
    );

    try {
      final authorization = _buildAuthHeader(
        method: 'POST',
        uri: uri,
        params: params,
      );

      final res = await http.post(
        uri,
        headers: {'Authorization': authorization},
      );

      if (res.statusCode == 200) {
        return res.body;
      } else {
        throw Exception('HttpCode: ${res.statusCode}, Body: ${res.body}');
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
    final requestSecretKey = params['oauth_token_secret'];

    final signature = _createSignature(
      method: method,
      uri: uri,
      timestamp: timestamp,
      nonce: nonce,
      params: params,
      requestSecretKey: requestSecretKey ?? '',
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
    String requestSecretKey = '',
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

    final encodedSecretKey = Uri.encodeComponent(apiSecretKey);
    final encodedSecretRequestKey = Uri.encodeComponent(requestSecretKey);

    final signingKey = '$encodedSecretKey&$encodedSecretRequestKey';

    final hmacSha1 = Hmac(sha1, signingKey.codeUnits);
    final digest = hmacSha1.convert(signatureBaseString.codeUnits);
    final signature = base64.encode(digest.bytes);

    return Uri.encodeComponent(signature);
  }
}
