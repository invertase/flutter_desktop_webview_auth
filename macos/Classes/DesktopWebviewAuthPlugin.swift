import Cocoa
import FlutterMacOS

import Foundation

import Cocoa
import FlutterMacOS
import WebKit

public class WebviewController: NSViewController, WKNavigationDelegate {
    var width: CGFloat?
    var height: CGFloat?
    var targetUriFragment: String?
    var result: FlutterResult?
    var onComplete: ((String?) -> Void)?
    var onDismissed: (() -> Void)?
    
    public override func loadView() {
        self.title = ""
        let webView = WKWebView(frame: NSMakeRect(0, 0, width ?? 980, height ?? 720))
        
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        
        view = webView
    }
    
    func loadUrl(_ url: String) {
        clearCookies()
        
        let url = URL(string: url)!
        let request = URLRequest(url: url)
        (view as! WKWebView).load(request)
    }
    
    func clearCookies() {
        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
        
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            records.forEach { record in
                WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
            }
        }
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        if navigationAction.navigationType == .formSubmitted {
            // Call the decisionHandler to allow the navigation to continue
            decisionHandler(.allow)
            return
        }

        guard let url = navigationAction.request.url else {
            decisionHandler(.allow);
            return
        }
        
        let uriString = url.absoluteString
        
        if uriString.contains(targetUriFragment!) {
            decisionHandler(.cancel)
            onComplete!(uriString)
            dismiss(self)
        } else {
            decisionHandler(.allow)
        }
    }
    
    public override func viewDidDisappear() {
        onDismissed!();
    }
}

public class DesktopWebviewAuthPlugin: NSObject, FlutterPlugin {
    var channel: FlutterMethodChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "io.invertase.flutter/desktop_webview_auth",
            binaryMessenger: registrar.messenger
        )
        
        let instance = DesktopWebviewAuthPlugin()
        instance.channel = channel
        
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "signIn":
            let args = call.arguments as! NSDictionary

            signIn(
                signInUrl: args["signInUri"] as! String,
                redirectUri: args["redirectUri"] as! String,
                width: args["width"] as? CGFloat,
                height: args["height"] as? CGFloat
            )

            result(nil)
            break
        case "recaptchaVerification":
            let args = call.arguments as! NSDictionary

            verifyRecaptcha(
                url: args["redirectUrl"] as! String,
                width: args["width"] as? CGFloat,
                height: args["height"] as? CGFloat
            )

            result(nil)
            break
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    func signIn(signInUrl: String, redirectUri: String, width: CGFloat?, height: CGFloat?) {
        _openWebview(
            url: signInUrl,
            flow: "signIn",
            targetUriFragment: redirectUri,
            width: width,
            height: height
        )
    }
    
    
    func verifyRecaptcha(url: String, width: CGFloat?, height: CGFloat?) {
        _openWebview(
            url: url,
            flow: "recaptchaVerification",
            targetUriFragment: "response",
            width: width,
            height: height
        )
    }
    
    func _openWebview(url: String, flow: String, targetUriFragment: String, width: CGFloat?,
                      height: CGFloat?) {

        let appWindow = NSApplication.shared.windows.first!
        let webviewController = WebviewController()
        
        webviewController.targetUriFragment = targetUriFragment
        webviewController.width = width
        webviewController.height = height

        webviewController.onComplete = { (callbackUrl) -> Void in
            let arguments = [
                "flow": flow,
                "url": callbackUrl
            ]
            
            self.channel!.invokeMethod("onCallbackUrlReceived", arguments: arguments)
        }
        
        webviewController.onDismissed = { () -> Void in
            self.channel!.invokeMethod("onDismissed", arguments: ["flow": flow])
            
        }

        webviewController.loadUrl(url)
        appWindow.contentViewController?.presentAsModalWindow(webviewController)
    }
}
