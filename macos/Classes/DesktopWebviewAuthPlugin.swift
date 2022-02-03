import Cocoa
import FlutterMacOS

import Foundation

import Cocoa
import FlutterMacOS
import WebKit

public class WebviewController: NSViewController, WKNavigationDelegate {
    var width: CGFloat?
    var height: CGFloat?
    var redirectUri: String?
    var result: FlutterResult?
    var onComplete: ((String?) -> Void)?
    
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
        
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow);
            return
        }
        
        let uriString = url.absoluteString
        
        if (uriString.starts(with: redirectUri!)) {
            decisionHandler(.cancel)
            onComplete!(uriString)
            dismiss(self)
        } else {
            decisionHandler(.allow)
        }
    }
    
    public override func viewDidDisappear() {
        onComplete!(nil)
    }
}

public class DesktopWebviewAuthPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "io.invertase.flutter/desktop_webview_auth",
            binaryMessenger: registrar.messenger
        )
        
        let instance = DesktopWebviewAuthPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "signIn":
            let args = call.arguments as! NSDictionary
            signIn(
                signInUri: args["signInUri"] as! String,
                redirectUri: args["redirectUri"] as! String,
                width: args["width"] as? CGFloat,
                height: args["height"] as? CGFloat,
                result: result
            )
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    func signIn(signInUri: String, redirectUri: String, width: CGFloat?, height: CGFloat?, result: @escaping FlutterResult) {
        let appWindow = NSApplication.shared.windows.first!
        let webviewController = WebviewController()
        
        webviewController.redirectUri = redirectUri
        webviewController.width = width
        webviewController.height = height
        webviewController.onComplete = { (callbackUrl) -> Void in
            result(callbackUrl)
        }
        
        webviewController.loadUrl(signInUri)
        
        appWindow.contentViewController?.presentAsModalWindow(webviewController)
    }
}
