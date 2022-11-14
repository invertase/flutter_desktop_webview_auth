import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'desktop_webview_auth_method_channel.dart';

/// Stub platform interface
///
/// For actual implementation, see [desktop_webview_auth](./desktop_webview_auth.dart)
abstract class DesktopWebviewAuthPlatform extends PlatformInterface {
  DesktopWebviewAuthPlatform() : super(token: _token);

  static final Object _token = Object();

  static DesktopWebviewAuthPlatform _instance =
      MethodChannelDesktopWebviewAuth();

  /// The default instance of [DesktopWebviewAuthPlatform] to use.
  ///
  /// Defaults to [MethodChannelDesktopWebviewAuth].
  static DesktopWebviewAuthPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [DesktopWebviewAuthPlatform] when
  /// they register themselves.
  static set instance(DesktopWebviewAuthPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }
}
