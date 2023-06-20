import 'dart:async';

import 'package:desktop_webview_auth/src/jsonable.dart';
import 'package:desktop_webview_auth/src/platform_response.dart';
import 'package:desktop_webview_auth/src/recaptcha_args.dart';
import 'package:desktop_webview_auth/src/recaptcha_result.dart';
import 'package:desktop_webview_auth/src/recaptcha_verification_server.dart';
import 'package:flutter/services.dart';

import 'src/auth_result.dart';
import 'src/provider_args.dart';

export 'src/provider_args.dart';
export 'src/recaptcha_args.dart' show RecaptchaArgs;
export 'src/auth_result.dart';
export 'src/recaptcha_result.dart';

const _channelName = 'io.invertase.flutter/desktop_webview_auth';

class DesktopWebviewAuth {
  static final _channel = const MethodChannel(_channelName)
    ..setMethodCallHandler(_onMethodCall);

  static late Completer<RecaptchaResult?> _recaptchaVerificationCompleter;

  static late ProviderArgs _args;
  static late Completer<AuthResult?> _signInResultCompleter;

  static _invokeMethod<T>({
    required String name,
    required JsonSerializable args,
    num? width,
    num? height,
  }) async {
    final args0 = await args.toJson();

    return _channel.invokeMethod<T>(name, {
      if (width != null) 'width': width.toInt(),
      if (height != null) 'height': height.toInt(),
      ...args0,
    });
  }

  static Future<void> _invokeSignIn(
    ProviderArgs args, [
    int? width,
    int? height,
  ]) async {
    return await _invokeMethod<void>(
      name: 'signIn',
      args: args,
      width: width,
      height: height,
    );
  }

  static Future<void> _invokeRecaptchaVerification(
    RecaptchaArgs args, [
    int? width,
    int? height,
  ]) async {
    return _invokeMethod<void>(
      name: 'recaptchaVerification',
      args: args,
      width: width,
      height: height,
    );
  }

  static Future<void> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onCallbackUrlReceived':
        final args = call.arguments.cast<String, dynamic>();
        final res = PlatformResponse.fromJson(args);

        if (res.flow == 'signIn') {
          await _onSignInCallbackUrlReceived(res.url);
        } else if (res.flow == 'recaptchaVerification') {
          _onRecaptchaCallbackUrlReceived(res.url);
        }
        break;

      case 'onDismissed':
        final args = call.arguments.cast<String, dynamic>();
        final res = PlatformResponse.fromJson(args);

        if (res.flow == 'signIn') {
          _onDismissed(_signInResultCompleter);
        } else if (res.flow == 'recaptchaVerification') {
          _onDismissed(_recaptchaVerificationCompleter);
        }
        break;

      default:
        throw UnimplementedError('${call.method} is not implemented');
    }
  }

  static void _onDismissed(Completer completer) {
    if (completer.isCompleted) return;
    completer.complete();
  }

  static void _onRecaptchaCallbackUrlReceived(String? callbackUrl) {
    if (callbackUrl == null) {
      _recaptchaVerificationCompleter.complete(null);
    } else {
      final parsedUri = Uri.parse(callbackUrl);
      final response = parsedUri.queryParameters['response'];
      final result = RecaptchaResult(response);
      _recaptchaVerificationCompleter.complete(result);
    }
  }

  static Future<void> _onSignInCallbackUrlReceived(String? callbackUrl) async {
    if (callbackUrl == null) {
      _signInResultCompleter.complete(null);
    } else {
      try {
        final authResult = _args.authorizeFromCallback(callbackUrl);
        _signInResultCompleter.complete(authResult);
      } catch (e) {
        _signInResultCompleter.complete(null);
      }
    }
  }

  static Future<RecaptchaResult?> recaptchaVerification(
    RecaptchaArgs args, {
    int? width,
    int? height,
  }) async {
    _recaptchaVerificationCompleter = Completer<RecaptchaResult?>();
    final server = RecaptchaVerificationServer(args);

    server.onError = (e) {
      _recaptchaVerificationCompleter.completeError(e);
    };

    await server.start();

    final invokeArgs = RecaptchaVerificationInvokeArgs.fromArgs(
      args,
      server.url,
    );

    await _invokeRecaptchaVerification(invokeArgs, width, height);

    return _recaptchaVerificationCompleter.future
        .whenComplete(server.close)
        .timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        server.close();
        return null;
      },
    );
  }

  static Future<AuthResult?> signIn(
    ProviderArgs args, {
    int? width,
    int? height,
  }) async {
    _args = args;
    _signInResultCompleter = Completer<AuthResult?>();

    try {
      await _invokeSignIn(args, width, height);
      return _signInResultCompleter.future;
    } catch (_) {
      return null;
    }
  }
}
