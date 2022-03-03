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
using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

// Pointer to WebViewController
static wil::com_ptr<ICoreWebView2Controller> webviewController;

// Pointer to WebView window
static wil::com_ptr<ICoreWebView2> webviewWindow;

namespace {
	template <typename T>
	std::optional<T> GetOptionalValue(const flutter::EncodableMap& map,
		const std::string& key) {
		const auto it = map.find(flutter::EncodableValue(key));
		if (it != map.end()) {
			const auto val = std::get_if<T>(&it->second);
			if (val) {
				return *val;
			}
		}
		return std::nullopt;
	}

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
			std::unique_ptr<flutter::MethodResult<EncodableValue>> result);
	};

	// static
	void DesktopWebviewAuthPlugin::RegisterWithRegistrar(
		flutter::PluginRegistrarWindows *registrar) {
		auto channel =
			std::make_unique<flutter::MethodChannel<EncodableValue>>(
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
		wc.lpszClassName = L"WebView Window";
		wc.lpfnWndProc = &DefWindowProc;

		RegisterClass(&wc);
	}

	DesktopWebviewAuthPlugin::~DesktopWebviewAuthPlugin() {
		UnregisterClass(wc.lpszClassName, nullptr);
	}

	void DesktopWebviewAuthPlugin::HandleMethodCall(
		const flutter::MethodCall<EncodableValue> &method_call,
		std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {

		const auto& args = std::get<flutter::EncodableMap>(*method_call.arguments());

		if (method_call.method_name().compare("signIn") == 0) {

			std::optional<std::string> signInUrl =
				GetOptionalValue<std::string>(args, "signInUri");

			HWND hWndWebView = CreateWindowExA(
				WS_EX_OVERLAPPEDWINDOW,
				"WebView Window",
				"",
				WS_OVERLAPPEDWINDOW,
				(GetSystemMetrics(SM_CXSCREEN) / 2) - (980 / 2), 
				(GetSystemMetrics(SM_CYSCREEN) / 2) - (720 / 2), 
				980, 720,
				view_->GetNativeWindow(),
				NULL,
				wc.hInstance,
				NULL
			);

			ShowWindow(hWndWebView, 1);

			CreateCoreWebView2EnvironmentWithOptions(nullptr, nullptr, nullptr,
				Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
					[hWndWebView, signInUrl](HRESULT result, ICoreWebView2Environment* env) -> HRESULT {

						// Create a CoreWebView2Controller and get the associated CoreWebView2 whose parent is the main window hWnd
						env->CreateCoreWebView2Controller(hWndWebView, Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
							[hWndWebView, signInUrl](HRESULT result, ICoreWebView2Controller* controller) -> HRESULT {
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
								GetClientRect(hWndWebView, &bounds);
								webviewController->put_Bounds(bounds);

								std::wstring stemp = std::wstring(signInUrl->begin(), signInUrl->end());
								LPCWSTR url = stemp.c_str();
								webviewWindow->Navigate(url);

								// 4 - Navigation events

								// 5 - Scripting

								// 6 - Communication between host and web content

								return S_OK;
							}).Get());
						return S_OK;
					}).Get());

			result->Success(flutter::EncodableValue());
		}
		else if (method_call.method_name().compare("recaptchaVerification") == 0) {
			//result->Success(flutter::EncodableValue(version_stream.str()));
			result->NotImplemented();
		}
		else {
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
