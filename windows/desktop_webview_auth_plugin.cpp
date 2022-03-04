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
#include <atlstr.h>

#include "WebView2.h"

using namespace Microsoft::WRL;

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

using std::string;
using std::unique_ptr;
using wil::com_ptr;

const string kWebViewClassName = "WebView";
const string kFlutterChannelName = "io.invertase.flutter/desktop_webview_auth";

namespace {
	class DesktopWebviewAuthPlugin : public flutter::Plugin {
	public:
		static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

		DesktopWebviewAuthPlugin(flutter::FlutterView* view);

		virtual ~DesktopWebviewAuthPlugin();

	private:
		WNDCLASS wc = { };

		string  redirectUrl_ = "";

		unique_ptr<flutter::FlutterView> view_;

		unique_ptr<flutter::MethodChannel<EncodableValue>> channel_;

		// Pointer to WebViewController
		com_ptr<ICoreWebView2Controller> webviewController;

		// Pointer to WebView window
		com_ptr<ICoreWebView2> webview_ = wil::com_ptr<ICoreWebView2>();

		HWND hWndWebView;

		/// <summary>
		/// Called when a method is called on this plugin's channel from Dart.
		/// </summary>
		/// <param name="method_call"></param>
		/// <param name="result"></param>
		void HandleMethodCall(
			const flutter::MethodCall<flutter::EncodableValue>& method_call,
			std::unique_ptr<flutter::MethodResult<EncodableValue>> result);
		/// <summary>
		/// Callback that triggers when the url changes.
		/// Closes the WebView and returns a result once the redirect with response is received.
		/// </summary>
		/// <param name="url"></param>
		/// <returns></returns>
		HRESULT url_changed_callback_(const std::string url);

		/// <summary>
		///  Clear coockies of the current WebView.
		/// </summary>
		/// <returns>Status of clearning the cookies, true for success.</returns>
		bool ClearCookies();

		std::optional<std::string> GetString(const flutter::EncodableMap& map,
			const std::string& key);
	};

	// static.
	void DesktopWebviewAuthPlugin::RegisterWithRegistrar(
		flutter::PluginRegistrarWindows* registrar) {
		auto plugin = std::make_unique<DesktopWebviewAuthPlugin>(registrar->GetView());

		plugin->channel_ =
			std::make_unique<flutter::MethodChannel<EncodableValue>>(
				registrar->messenger(), kFlutterChannelName,
				&flutter::StandardMethodCodec::GetInstance());

		plugin->channel_->SetMethodCallHandler(
			[plugin_pointer = plugin.get()](const auto& call, auto result) {
			plugin_pointer->HandleMethodCall(call, std::move(result));
		});


		registrar->AddPlugin(std::move(plugin));
	}

	// constructor.
	DesktopWebviewAuthPlugin::DesktopWebviewAuthPlugin(flutter::FlutterView* view) : view_(view) {
		// Convert short to wide string.
		const auto temp = std::wstring(kWebViewClassName.begin(), kWebViewClassName.end());

		wc.lpszClassName = temp.c_str();
		wc.lpfnWndProc = &DefWindowProc;

		channel_ = std::unique_ptr<flutter::MethodChannel<EncodableValue>>();

		RegisterClass(&wc);
	}

	DesktopWebviewAuthPlugin::~DesktopWebviewAuthPlugin() {
		UnregisterClass(wc.lpszClassName, nullptr);
	}

	void DesktopWebviewAuthPlugin::HandleMethodCall(
		const flutter::MethodCall<EncodableValue>& method_call,
		std::unique_ptr<flutter::MethodResult<EncodableValue>> flutterResult) {

		// Get args coming from Dart.
		const auto& args = std::get<flutter::EncodableMap>(*method_call.arguments());

		if (method_call.method_name().compare("signIn") == 0) {

			std::optional<std::string> signInUrl = GetString(args, "signInUri");
			std::optional<std::string> redirectUrl = GetString(args, "redirectUri");

			redirectUrl_ = redirectUrl.value();

			HWND hWnd = CreateWindowExA(
				WS_EX_OVERLAPPEDWINDOW,
				kWebViewClassName.c_str(),
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

			hWndWebView = hWnd;

			if (hWndWebView) {
				ShowWindow(hWndWebView, 1);
			}

			CreateCoreWebView2EnvironmentWithOptions(nullptr, nullptr, nullptr,
				Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
					[signInUrl, &flutterResult, this](HRESULT result, ICoreWebView2Environment* env) -> HRESULT {
						// Create a CoreWebView2Controller and get the associated CoreWebView2 whose parent is the main window hWnd
						env->CreateCoreWebView2Controller(hWndWebView, Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
							[signInUrl, &flutterResult, this](HRESULT result, ICoreWebView2Controller* controller) -> HRESULT {
								if (controller != nullptr) {
									webviewController = controller;
									webviewController->get_CoreWebView2(&webview_);
								}

								// Add a few settings for the webview
								// The demo step is redundant since the values are the default settings
								ICoreWebView2Settings* Settings;
								webview_->get_Settings(&Settings);
								Settings->put_IsScriptEnabled(TRUE);
								Settings->put_AreDefaultScriptDialogsEnabled(TRUE);
								Settings->put_IsWebMessageEnabled(TRUE);

								// Resize the WebView2 control to fit the bounds of the parent window
								RECT bounds;
								GetClientRect(hWndWebView, &bounds);
								webviewController->put_Bounds(bounds);

								std::wstring stemp = std::wstring(signInUrl->begin(), signInUrl->end());
								LPCWSTR url = stemp.c_str();

								webview_->Navigate(url);

								EventRegistrationToken token;
								webview_->add_NavigationCompleted(
									Callback<ICoreWebView2NavigationCompletedEventHandler>(
										[&flutterResult, this](ICoreWebView2* sender, IUnknown* args) -> HRESULT {
											LPWSTR wurl;
											if (webview_->get_Source(&wurl) == S_OK) {
												std::string url = CW2A(wurl, CP_UTF8);

												return url_changed_callback_(url);
											}

											return S_OK;
										})
									.Get(), &token);

								return S_OK;
							}).Get());
						return S_OK;
					}).Get());

			flutterResult->Success(flutter::EncodableValue());
		}
		else if (method_call.method_name().compare("recaptchaVerification") == 0) {
			//result->Success(flutter::EncodableValue(version_stream.str()));
			flutterResult->NotImplemented();
		}
		else {
			flutterResult->NotImplemented();
		}
	}

	HRESULT DesktopWebviewAuthPlugin::url_changed_callback_(const std::string url)
	{
		if (url.rfind(redirectUrl_, 0) == 0) {

			ClearCookies();
			auto result = std::make_unique<EncodableValue>(EncodableMap{ {"url", url},{"flow", "signIn"} });

			channel_->InvokeMethod("onCallbackUrlReceived", std::move(result), nullptr);

			DestroyWindow(hWndWebView);

			return S_OK;
		}

		return S_OK;
	}

	bool DesktopWebviewAuthPlugin::ClearCookies()
	{
		return webview_->CallDevToolsProtocolMethod(L"Network.clearBrowserCookies",
			L"{}", nullptr) == S_OK;
	}

	std::optional<std::string> DesktopWebviewAuthPlugin::GetString(
		const flutter::EncodableMap& map, 
		const std::string& key)
	{
		const auto it = map.find(flutter::EncodableValue(key));
		if (it != map.end()) {
			const auto val = std::get_if<std::string>(&it->second);
			if (val) {
				return *val;
			}
		}
		return std::nullopt;
	}
}  // namespace

void DesktopWebviewAuthPluginRegisterWithRegistrar(
	FlutterDesktopPluginRegistrarRef registrar) {
	DesktopWebviewAuthPlugin::RegisterWithRegistrar(
		flutter::PluginRegistrarManager::GetInstance()
		->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));

}
