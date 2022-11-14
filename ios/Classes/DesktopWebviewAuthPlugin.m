#import "DesktopWebviewAuthPlugin.h"
#if __has_include(<desktop_webview_auth/desktop_webview_auth-Swift.h>)
#import <desktop_webview_auth/desktop_webview_auth-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "desktop_webview_auth-Swift.h"
#endif

@implementation DesktopWebviewAuthPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftDesktopWebviewAuthPlugin registerWithRegistrar:registrar];
}
@end
