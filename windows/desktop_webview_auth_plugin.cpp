#include "include/desktop_webview_auth/desktop_webview_auth_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <map>
#include <memory>
#include <sstream>

#include <WebView2.h>

namespace {

class DesktopWebviewAuthPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  DesktopWebviewAuthPlugin(flutter::FlutterView* view);

  virtual ~DesktopWebviewAuthPlugin();

 private:
  WNDCLASS wc = { };

  std::unique_ptr<flutter::FlutterView> view_;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

// static
void DesktopWebviewAuthPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "io.invertase.flutter/desktop_webview_auth",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<DesktopWebviewAuthPlugin>(registrar->GetView());

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

DesktopWebviewAuthPlugin::DesktopWebviewAuthPlugin(flutter::FlutterView* view) : view_(view) {
  wc.lpszClassName =  L"WebView Window";
  wc.lpfnWndProc = &DefWindowProc;

  RegisterClass(&wc);
}

DesktopWebviewAuthPlugin::~DesktopWebviewAuthPlugin() {
  UnregisterClass(wc.lpszClassName, nullptr);
}

void DesktopWebviewAuthPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (method_call.method_name().compare("signIn") == 0) {
      //HWND parentWindow = view_->GetNativeWindow();
      HWND hwnd = CreateWindowEx(
          0,                              // Optional window styles.
          L"WebView Window",                     // Window class
          L"Learn to Program Windows",    // Window text
          WS_OVERLAPPEDWINDOW,            // Window style

          // Size and position
          CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,

          view_->GetNativeWindow(),       // Parent window    
          NULL,       // Menu
          wc.hInstance,  // Instance handle
          NULL        // Additional application data
      );

      ShowWindow(hwnd, 1);

    result->Success(flutter::EncodableValue());
  } else if (method_call.method_name().compare("recaptchaVerification") == 0) {
    //result->Success(flutter::EncodableValue(version_stream.str()));
    result->NotImplemented();
  } else {
    result->NotImplemented();
  }
}

}  // namespace

void DesktopWebviewAuthPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  DesktopWebviewAuthPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));

}
