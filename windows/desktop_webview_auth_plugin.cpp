#include "include/desktop_webview_auth/desktop_webview_auth_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>
#include <stdlib.h>
#include <wrl.h>
#include <wil/com.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <map>
#include <memory>
#include <sstream>
#include <iostream>

#include "WebView2.h"

using namespace Microsoft::WRL;

// Pointer to WebViewController
static wil::com_ptr<ICoreWebView2Controller> webviewController;

// Pointer to WebView window
static wil::com_ptr<ICoreWebView2> webviewWindow;

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

      RECT rect;
      GetWindowRect(view_->GetNativeWindow(), &rect);

      HWND hWnd = CreateWindowExA(
          WS_EX_OVERLAPPEDWINDOW,
          "WebView Window",
          "",
          WS_OVERLAPPEDWINDOW,
          // Size and position
          rect.top, rect.top, 980, 720,
          view_->GetNativeWindow(),
          nullptr,
          wc.hInstance,
          nullptr
      );

      ShowWindow(hWnd, 1);

      // Step 3 - Create a single WebView within the parent window
      // Locate the browser and set up the environment for WebView
      CreateCoreWebView2EnvironmentWithOptions(nullptr, nullptr, nullptr,
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
            [hWnd](HRESULT result, ICoreWebView2Environment* env) -> HRESULT {

                  // Create a CoreWebView2Controller and get the associated CoreWebView2 whose parent is the main window hWnd
                  env->CreateCoreWebView2Controller(hWnd, Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                    [hWnd](HRESULT result, ICoreWebView2Controller* controller) -> HRESULT {
                    if (controller != nullptr) {
                        webviewController = controller;
                        webviewController->get_CoreWebView2(&webviewWindow);
                    }

                    // Add a few settings for the webview
                    // The demo step is redundant since the values are the default settings
                    ICoreWebView2Settings* Settings;
                    webviewWindow->get_Settings(&Settings);
                    Settings->put_IsScriptEnabled(TRUE);
                    Settings->put_AreDefaultScriptDialogsEnabled(TRUE);
                    Settings->put_IsWebMessageEnabled(TRUE);

                    // Resize the WebView2 control to fit the bounds of the parent window
                    RECT bounds;
                    GetClientRect(hWnd, &bounds);
                    webviewController->put_Bounds(bounds);

                    // Schedule an async task to navigate to Bing
                    webviewWindow->Navigate(L"https://www.google.com/");

                    // 4 - Navigation events

                    // 5 - Scripting

                    // 6 - Communication between host and web content

                    return S_OK;
                  }).Get());
            return S_OK;
        }).Get());

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
