import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:desktop_webview_auth/src/recaptcha_args.dart';
import 'package:desktop_webview_auth/src/recaptcha_result.dart';
import 'package:flutter/services.dart';

import 'src/auth_result.dart';
import 'src/provider_args.dart';
import 'src/recaptcha_html.dart';

export 'src/provider_args.dart';
export 'src/recaptcha_args.dart';
export 'src/auth_result.dart';
export 'src/recaptcha_result.dart';

class DesktopWebviewAuth {
  static const _channel =
      MethodChannel('io.invertase.flutter/desktop_webview_auth');

  static Future<String?> _invokeSignIn(ProviderArgs args,
      [int? width, int? height]) async {
    return _channel.invokeMethod<String>(
      'signIn',
      {
        'width': width?.toInt(),
        'height': height?.toInt(),
        ...await args.toJson()
      },
    );
  }

  static Future<String?> _invokeRecaptchaVerification(RecaptchaArgs args,
      [int? width, int? height]) async {
    return _channel.invokeMethod<String>(
      'recaptchaVerification',
      {
        'width': width?.toInt(),
        'height': height?.toInt(),
        ...await args.toJson()
      },
    );
  }

  static Future<RecaptchaResult?> recaptchaVerification(RecaptchaArgs args,
      {int? width, int? height}) async {
    final completer = Completer<RecaptchaResult?>();

    await args.getLocalServer();

    // Start listening to the local server.
    args.sub?.stream.listen((HttpRequest request) async {
      final uri = request.requestedUri;

      if (uri.path == '/' && uri.queryParameters.isEmpty) {
        await _sendDataToHTTP(
          request,
          recaptchaHTML(
            args.siteKey,
            args.siteToken,
            // theme: parameters['theme'],
            // size: parameters['size'],
          ),
        );
      } else if (uri.query.contains('response')) {
        await _sendDataToHTTP(
          request,
          responseHTML(
            'Success',
            'Successful verification!',
          ),
        );
      } else if (uri.query.contains('error-code')) {
        await _sendDataToHTTP(
          request,
          responseHTML(
            'Captcha check failed.',
            uri.queryParameters['error-code']!,
          ),
        );

        completer.completeError((e) {
          return Exception(uri.queryParameters['error-code']);
        });
      }
    });

    _channel.setMethodCallHandler((event) async {
      if (event.method == 'getCallbackUrl') {
        final callbackUrl = event.arguments;
        if (event.arguments != null) {
          completer.complete(RecaptchaResult(
              Uri.parse(callbackUrl).queryParameters['response']));
        } else {
          completer.complete(null);
        }
      } else {
        completer.complete(null);
      }
    });

    await _invokeRecaptchaVerification(args, width, height);

    return completer.future
        .whenComplete(args.closeLocalServer)
        .timeout(const Duration(seconds: 60));
  }

  static Future<void> _sendDataToHTTP(
    HttpRequest request,
    Object data, [
    String contentType = 'text/html',
  ]) async {
    request.response
      ..statusCode = 200
      ..headers.set('content-type', contentType)
      ..write(data);
    await request.response.close();
  }

  static Future<AuthResult?> signIn(ProviderArgs args,
      {int? width, int? height}) async {
    /// Future will complete once there's a
    final completer = Completer<AuthResult?>();

    /// On Linux, the callback comes back by a native invocation of the
    /// method `getCallbackUrl`.
    if (Platform.isLinux) {
      _channel.setMethodCallHandler((event) async {
        if (event.method == 'getCallbackUrl') {
          final callbackUrl = event.arguments;
          if (event.arguments != null) {
            final authResult = await args.authorizeFromCallback(callbackUrl);
            completer.complete(authResult);
          } else {
            completer.complete(null);
          }
        } else {
          completer.complete(null);
        }
      });
    }

    final callbackUrl = await _invokeSignIn(args, width, height);

    /// On macOS we get the callback by invoking `signIn` method.
    if (Platform.isMacOS) {
      if (callbackUrl == null) {
        completer.complete(null);
      } else {
        final authResult = await args.authorizeFromCallback(callbackUrl);
        completer.complete(authResult);
      }
    }

    return completer.future;
  }
}
