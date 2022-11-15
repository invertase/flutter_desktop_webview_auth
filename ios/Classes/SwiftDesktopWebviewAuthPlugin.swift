import Flutter
import UIKit

public class SwiftDesktopWebviewAuthPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "desktop_webview_auth", binaryMessenger: registrar.messenger())
    let instance = SwiftDesktopWebviewAuthPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    result(nil)
  }
}
