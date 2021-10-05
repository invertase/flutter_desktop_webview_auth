import 'dart:async';

import 'package:flutter/services.dart';

import 'src/auth_result.dart';
import 'src/provider_args.dart';

export 'src/auth_result.dart';
export 'src/provider_args.dart';

class DesktopWebviewAuth {
  static const _channel =
      MethodChannel('io.invertase.flutter/desktop_webview_auth');

  static Future<AuthResult?> signIn(ProviderArgs args) async {
    final callbackUrl = await _channel.invokeMethod<String>(
      'signIn',
      await args.toJson(),
    );

    if (callbackUrl == null) {
      return null;
    }

    final authResult = await args.authorizeFromCallback(callbackUrl);
    return authResult;
  }
}
