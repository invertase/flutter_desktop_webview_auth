import 'dart:async';

import 'package:desktop_webview_auth/src/jsonable.dart';
import 'package:desktop_webview_auth/src/platform_response.dart';
import 'package:desktop_webview_auth/src/recaptcha_args.dart';
import 'package:desktop_webview_auth/src/recaptcha_result.dart';
import 'package:desktop_webview_auth/src/recaptcha_verification_server.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:webviewx/webviewx.dart';
import 'src/auth_result.dart';
import 'src/provider_args.dart';

export 'src/provider_args.dart';
export 'src/recaptcha_args.dart' show RecaptchaArgs;
export 'src/auth_result.dart';
export 'src/recaptcha_result.dart';
import 'package:flutter/foundation.dart';
import 'src/recaptcha_html.dart';

const _channelName = 'io.invertase.flutter/desktop_webview_auth';

class DesktopWebviewAuth {
  static final _channel = const MethodChannel(_channelName)
    ..setMethodCallHandler(_onMethodCall);

  static late Completer<RecaptchaResult?> _recaptchaVerificationCompleter;

  static late ProviderArgs _args;
  static late Completer<AuthResult?> _signInResultCompleter;

  static _invokeMethod<T>({
    required String name,
    required Jsonable args,
    num? width,
    num? height,
  }) async {
    final _args = await args.toJson();

    return _channel.invokeMethod<T>(name, {
      if (width != null) 'width': width.toInt(),
      if (height != null) 'height': height.toInt(),
      ..._args,
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
          _onRecaptchaCallbackUrlReceived(res.url, null);
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

  static void _onRecaptchaCallbackUrlReceived(String? callbackUrl, BuildContext? context) {
    if (callbackUrl == null) {
      _recaptchaVerificationCompleter.complete(null);
    } else {
      final parsedUri = Uri.parse(callbackUrl);
      final response = parsedUri.queryParameters['response'];
      final result = RecaptchaResult(response);
      _recaptchaVerificationCompleter.complete(result);
      Navigator.pop(context!);
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
    double? width,
    double? height,
    required BuildContext context,
  }) async {
    _recaptchaVerificationCompleter = Completer<RecaptchaResult?>();
    final server = RecaptchaVerificationServer(args);

    server.onError = (e) {
      _recaptchaVerificationCompleter.completeError(e);
    };
    if(!kIsWeb)
      await server.start();
    await _openWebView(server.url, width, height, context, args.siteKey);

    return _recaptchaVerificationCompleter.future
        .whenComplete(server.close)
        .timeout(
      const Duration(seconds: 90),
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

  static _openWebView(String? url, double? width, double? height, BuildContext context, String siteKey) async {
    late WebViewXController webviewController;

    await Navigator.push(context, MaterialPageRoute(builder: (context) => Scaffold(
      appBar: AppBar(),
      body: WebViewX(
        initialContent: url ?? recaptchaHTML(siteKey, null),
        initialSourceType: url!=null ? SourceType.url: SourceType.html,
        onWebViewCreated: (controller) => webviewController = controller,
        height: height ?? 800,
        width: width ?? 600,
        onPageStarted: (page){
          print('WebView page: $page');
          if(Uri.parse(page).hasQuery)
            _onRecaptchaCallbackUrlReceived(page, context);
        },
      ),
    )));
  }
}
