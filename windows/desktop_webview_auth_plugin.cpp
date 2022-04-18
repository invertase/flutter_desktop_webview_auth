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
using flutter::MethodChannel;
using flutter::MethodCall;
using flutter::MethodResult;
using flutter::FlutterView;

using std::string;
using std::unique_ptr;
using wil::com_ptr;
using std::optional;

const string kWebViewClassName = "WebView";
const string kFlutterChannelName = "io.invertase.flutter/desktop_webview_auth";

namespace {

	class DesktopWebviewAuthPlugin : public flutter::Plugin {

	public:
		static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

		DesktopWebviewAuthPlugin(FlutterView* view);

		virtual ~DesktopWebviewAuthPlugin();
		
		LRESULT MessageHandler(HWND window,
			UINT const message,
			WPARAM const wparam,
			LPARAM const lparam);

	private:
		string  initialUrl_ = "";
		string  redirectUrl_ = "";
		string  methodName_ = "";
		
		WNDCLASS webViewWindowClass = { };

		// Register the token of Navigation event.
		EventRegistrationToken navigationToken;

		// The popup windows in which the WebView is loaded.
		HWND hWndWebView;

		// The current Flutter view.
		unique_ptr<FlutterView> view_;

		// Pointer to the Flutter MethodChannel.
		unique_ptr<MethodChannel<EncodableValue>> channel_;

		// Pointer to WebViewController
		com_ptr<ICoreWebView2Controller> webviewController;

		// Pointer to WebView window.
		com_ptr<ICoreWebView2> webview_ = wil::com_ptr<ICoreWebView2>();

		// Called when a method is called on this plugin's channel from Dart.
		void HandleMethodCall(
			const MethodCall<EncodableValue>& method_call,
			unique_ptr<MethodResult<EncodableValue>> result);

		// Open a new window showing a WebView with the desired width and height.
		void CreateWebView(optional<int> width, optional<int> height);

		// Callback that triggers when the url changes.
		// Closes the WebView and returns a result once the redirect with response is received.
		HRESULT UrlChangedCallback(const string url);

		//  Clear coockies of the current WebView.
		bool ClearCookies();
	};

	LRESULT CALLBACK WinProc(HWND hWindow, UINT uMsg, WPARAM wParam, LPARAM lParam)
	{
		DesktopWebviewAuthPlugin* plugin = reinterpret_cast<DesktopWebviewAuthPlugin*>(GetWindowLongPtr(hWindow, GWLP_USERDATA));

		if (plugin != nullptr) {

			return plugin->MessageHandler(hWindow, uMsg, wParam, lParam);  // Forward message to instance-aware WndProc
		}
		else {
			return DefWindowProc(hWindow, uMsg, wParam, lParam);
		}
	}

	LRESULT DesktopWebviewAuthPlugin::MessageHandler(HWND window,
		UINT const message,
		WPARAM const wparam,
		LPARAM const lparam)
	{
		switch (message)
		{
		case WM_CLOSE:
		{
			unique_ptr result = std::make_unique<EncodableValue>(EncodableMap{ {"flow", methodName_} });
			channel_->InvokeMethod("onDismissed", std::move(result), nullptr);

			DestroyWindow(window);
		}
		break;
		case WM_DESTROY:
		{
			ClearCookies();
			redirectUrl_ = "";
			initialUrl_ = "";
			webview_->remove_NavigationCompleted(navigationToken);
		}
		break;
		default:
		{
			return DefWindowProc(window, message, wparam, lparam);
		}
		break;
		}

		return 0;
	}

	// static.
	void DesktopWebviewAuthPlugin::RegisterWithRegistrar(
		flutter::PluginRegistrarWindows* registrar) {
		auto plugin = std::make_unique<DesktopWebviewAuthPlugin>(registrar->GetView());

		plugin->channel_ =
			std::make_unique<MethodChannel<EncodableValue>>(
				registrar->messenger(), kFlutterChannelName,
				&flutter::StandardMethodCodec::GetInstance());

		plugin->channel_->SetMethodCallHandler(
			[plugin_pointer = plugin.get()](const auto& call, auto result) {
			plugin_pointer->HandleMethodCall(call, std::move(result));
		});


		registrar->AddPlugin(std::move(plugin));
	}

	// Util to get a String out of a Flutter EncodableMap.
	optional<string> GetString(
		const EncodableMap& map,
		const string& key)
	{
		const auto it = map.find(EncodableValue(key));
		if (it != map.end()) {
			const auto val = std::get_if<string>(&it->second);
			if (val) {
				return *val;
			}
		}
		return std::nullopt;
	}

	// Util to get a int out of a Flutter EncodableMap.
	optional<int> GetInt(const EncodableMap& map, const string& key)
	{
		const auto it = map.find(EncodableValue(key));
		if (it != map.end()) {
			const auto val = std::get_if<int>(&it->second);
			if (val) {
				return *val;
			}
		}
		return std::nullopt;
	}

	// constructor.
	DesktopWebviewAuthPlugin::DesktopWebviewAuthPlugin(FlutterView* view) : view_(view) {
		// Convert short to wide string.
		const auto temp = std::wstring(kWebViewClassName.begin(), kWebViewClassName.end());

		webViewWindowClass.lpszClassName = temp.c_str();
		webViewWindowClass.lpfnWndProc = &WinProc;

		channel_ = std::unique_ptr<flutter::MethodChannel<EncodableValue>>();

		RegisterClass(&webViewWindowClass);
	}

	DesktopWebviewAuthPlugin::~DesktopWebviewAuthPlugin() {
		UnregisterClass(webViewWindowClass.lpszClassName, nullptr);
	}

	void DesktopWebviewAuthPlugin::HandleMethodCall(
		const flutter::MethodCall<EncodableValue>& method_call,
		std::unique_ptr<MethodResult<EncodableValue>> result) {

		// Get args coming from Dart.
		const auto& args = std::get<EncodableMap>(*method_call.arguments());
		optional<int> width = GetInt(args, "width");
		optional<int> height = GetInt(args, "height");

		methodName_ = method_call.method_name();

		if (methodName_.compare("signIn") == 0) {

			optional<string> signInUrl = GetString(args, "signInUri");
			optional<string> redirectUrl = GetString(args, "redirectUri");

			initialUrl_ = signInUrl.value();
			redirectUrl_ = redirectUrl.value();

			CreateWebView(width, height);

			result->Success(EncodableValue());
		}
		else if (methodName_.compare("recaptchaVerification") == 0) {
			optional<string> redirectUrl = GetString(args, "redirectUrl");
			initialUrl_ = redirectUrl.value();

			CreateWebView(width, height);
			result->Success(EncodableValue());
		}
		else {
			result->NotImplemented();
		}
	}

	HRESULT DesktopWebviewAuthPlugin::UrlChangedCallback(const std::string url)
	{
		bool matching = false;

		if (methodName_.compare("signIn") == 0) {
			matching = url.rfind(redirectUrl_, 0) == 0;
		}
		else if (methodName_.compare("recaptchaVerification") == 0) {
			matching = url.find("response") != string::npos;
		}

		if (matching) {
			auto result = std::make_unique<EncodableValue>(EncodableMap{ {"url", url}, {"flow", methodName_} });

			channel_->InvokeMethod("onCallbackUrlReceived", std::move(result), nullptr);

			DestroyWindow(hWndWebView);
		}

		return S_OK;
	}


	bool DesktopWebviewAuthPlugin::ClearCookies()
	{
		return webview_->CallDevToolsProtocolMethod(L"Network.clearBrowserCookies",
			L"{}", nullptr) == S_OK;
	}


	void DesktopWebviewAuthPlugin::CreateWebView(optional<int> width, optional<int> height)
	{
		if (!width.has_value()) {
			width = GetSystemMetrics(SM_CXSCREEN) / 2;
		}

		if (!height.has_value()) {
			height = GetSystemMetrics(SM_CYSCREEN) / 2;
		}

		hWndWebView = CreateWindowExA(
			WS_EX_DLGMODALFRAME,
			kWebViewClassName.c_str(),
			"",
			WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU,
			(GetSystemMetrics(SM_CXSCREEN) / 2) - (width.value() / 2),
			(GetSystemMetrics(SM_CYSCREEN) / 2) - (height.value() / 2),
			width.value(), height.value(),
			view_->GetNativeWindow(),
			NULL,
			webViewWindowClass.hInstance,
			NULL
		);

		SetWindowLongPtr(hWndWebView, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));

		ShowWindow(hWndWebView, 1);

		CreateCoreWebView2EnvironmentWithOptions(nullptr, nullptr, nullptr,
			Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
				[this](HRESULT result, ICoreWebView2Environment* env) -> HRESULT {
					// Create a CoreWebView2Controller and get the associated CoreWebView2 whose parent is the main window hWnd
					env->CreateCoreWebView2Controller(hWndWebView, Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
						[this](HRESULT result, ICoreWebView2Controller* controller) -> HRESULT {
							if (controller != nullptr) {
								webviewController = controller;
								webviewController->get_CoreWebView2(&webview_);
							}

							// Add a few settings for the webview
							wil::com_ptr<ICoreWebView2Settings> Settings;
							wil::com_ptr<ICoreWebView2Settings2> Settings2_;

							webview_->get_Settings(&Settings);
							
							Settings2_ = Settings.try_query<ICoreWebView2Settings2>();
							
							Settings->put_IsScriptEnabled(TRUE);
							Settings->put_AreDefaultScriptDialogsEnabled(FALSE);
							Settings->put_IsWebMessageEnabled(FALSE);
							Settings->put_AreHostObjectsAllowed(FALSE);
							Settings2_->put_UserAgent(L"Chrome");

							// Resize the WebView2 control to fit the bounds of the parent window
							RECT bounds;
							GetClientRect(hWndWebView, &bounds);
							webviewController->put_Bounds(bounds);

							std::wstring stemp = std::wstring(initialUrl_.begin(), initialUrl_.end());
							LPCWSTR url = stemp.c_str();

							webview_->Navigate(url);

							webview_->add_NavigationCompleted(
								Callback<ICoreWebView2NavigationCompletedEventHandler>(
									[this](ICoreWebView2* sender, IUnknown* args) -> HRESULT {
										LPWSTR wurl;
										if (webview_->get_Source(&wurl) == S_OK) {
											string url = CW2A(wurl, CP_UTF8);

											return UrlChangedCallback(url);
										}

										return S_OK;
									})
								.Get(), &navigationToken);

							return S_OK;
						}).Get());
					return S_OK;
				}).Get());
	}
}  // namespace

void DesktopWebviewAuthPluginRegisterWithRegistrar(
	FlutterDesktopPluginRegistrarRef registrar) {
	DesktopWebviewAuthPlugin::RegisterWithRegistrar(
		flutter::PluginRegistrarManager::GetInstance()
		->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}

