import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'src/auth_result.dart';
import 'src/provider_args.dart';

export 'src/auth_result.dart';
export 'src/provider_args.dart';

class DesktopWebviewAuth {
  static const _channel =
      MethodChannel('io.invertase.flutter/desktop_webview_auth');

  static Future<String?> _invokeSignIn(ProviderArgs args) async {
    return _channel.invokeMethod<String>(
      'signIn',
      await args.toJson(),
    );
  }

  static Future<AuthResult?> signIn(ProviderArgs args) async {
    /// Future will complete once there's a
    final completer = Completer<AuthResult?>();

    /// On Linux, the callback comes back by a native invocation of the
    /// method `getCallbackUrl`.
    if (Platform.isLinux) {
      _channel.setMethodCallHandler((event) async {
        if (event.method == 'getCallbackUrl') {
          final callbackUrl = event.arguments;
          final authResult = await args.authorizeFromCallback(callbackUrl);
          completer.complete(authResult);
        } else {
          completer.complete(null);
        }
      });
    }

    final callbackUrl = await _invokeSignIn(args);

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
