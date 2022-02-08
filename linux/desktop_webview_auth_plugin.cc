#include "include/desktop_webview_auth/desktop_webview_auth_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <glib.h>
#include <cstring>

#include <webkit2/webkit2.h>

#define DESKTOP_WEBVIEW_AUTH_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), desktop_webview_auth_plugin_get_type(), \
                              DesktopWebviewAuthPlugin))

struct _DesktopWebviewAuthPlugin
{
  GObject parent_instance;
  FlPluginRegistrar *registrar;
  FlMethodChannel *method_channel;
  gulong load_change_handler;
  gchar *redirectUrl;
  gchar *callbackUrl;
  GtkWidget *popupWindow;
  WebKitWebContext *context;
};

G_DEFINE_TYPE(DesktopWebviewAuthPlugin, desktop_webview_auth_plugin, g_object_get_type())

static void changed(WebKitWebView *view, WebKitLoadEvent event, gpointer user_data)
{
  DesktopWebviewAuthPlugin* plugin = DESKTOP_WEBVIEW_AUTH_PLUGIN(user_data);

  const gchar *uri = webkit_web_view_get_uri(view);
  const gchar *redirectUrl = plugin->redirectUrl;

  char str[(int)strlen(redirectUrl)];
  const gchar *copy = strncpy(str, (char *)uri, (int)strlen(redirectUrl));

  bool matching = strcmp(copy, redirectUrl) == 0;

  if (event == WEBKIT_LOAD_FINISHED && matching)
  {
    webkit_web_context_clear_cache (plugin->context);

    plugin->callbackUrl = (gchar *)webkit_web_view_get_uri(view);
    g_autoptr(FlValue) result = fl_value_new_string(plugin->callbackUrl);

    fl_method_channel_invoke_method(plugin->method_channel, "getCallbackUrl",
                                    result, nullptr, nullptr, user_data);

    g_free(plugin->redirectUrl);
    g_signal_handler_disconnect(G_OBJECT(view), plugin->load_change_handler);

    gtk_window_close(GTK_WINDOW(plugin->popupWindow));
  }
}

// Called if the user destroyed the window before sending the auth callback url.
static void destroy(GtkWidget *widget, gpointer user_data)
{
  DesktopWebviewAuthPlugin* plugin = DESKTOP_WEBVIEW_AUTH_PLUGIN(user_data);

  if (!plugin->callbackUrl)
  {
    fl_method_channel_invoke_method(plugin->method_channel, "getCallbackUrl",
                                    nullptr, nullptr, nullptr, user_data);
  }
}

// Called when a method call is received from Flutter.
static void desktop_webview_auth_plugin_handle_method_call(FlMethodCall *method_call, gpointer user_data)
{
  DesktopWebviewAuthPlugin* plugin = DESKTOP_WEBVIEW_AUTH_PLUGIN(user_data);

  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar *method = fl_method_call_get_name(method_call);
  FlValue *args = fl_method_call_get_args(method_call);

  if (strcmp(method, "signIn") == 0)
  {
    FlView *view = fl_plugin_registrar_get_view(plugin->registrar);
    GtkWindow *window = GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
    GtkWidget *popup = gtk_window_new(GTK_WINDOW_TOPLEVEL);

    gtk_window_set_transient_for(GTK_WINDOW(popup), GTK_WINDOW(window));

    GtkWidget *scrollview = gtk_scrolled_window_new(nullptr, nullptr);

    plugin->context = webkit_web_context_new ();
    GtkWidget *webview = webkit_web_view_new_with_context (plugin->context);

    gtk_container_add(GTK_CONTAINER(scrollview), webview);
    gtk_container_add(GTK_CONTAINER(popup), scrollview);

    FlValue *signInUriValue = fl_value_lookup_string(args, "signInUri");
    const gchar *signInUri = fl_value_get_string(signInUriValue);

    FlValue *redirectUrlValue = fl_value_lookup_string(args, "redirectUri");
    const gchar *redirectUrl = fl_value_get_string(redirectUrlValue);

    FlValue *widthString = fl_value_lookup_string(args, "width");
    FlValue *heightString = fl_value_lookup_string(args, "height");
    FlValue *dartNull = fl_value_new_null();

    int width = 920;
    int height = 720;

    if (!fl_value_equal(widthString, dartNull))
    {
      width = fl_value_get_int(widthString);
    }

    if (!fl_value_equal(heightString, dartNull))
    {
      height = fl_value_get_int(heightString);
    }

    webkit_web_view_load_uri(WEBKIT_WEB_VIEW(webview), signInUri);

    gtk_window_set_position(GTK_WINDOW(popup), GTK_WIN_POS_MOUSE);
    gtk_window_set_default_size(GTK_WINDOW(popup), width, height);

    plugin->redirectUrl = g_strdup(redirectUrl);
    plugin->popupWindow = popup;

    plugin->load_change_handler = g_signal_connect(G_OBJECT(webview), "load-changed", G_CALLBACK(changed), user_data);
    g_signal_connect(G_OBJECT(popup), "destroy", G_CALLBACK(destroy), user_data);

    gtk_widget_show_all(popup);

    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  else
  {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void desktop_webview_auth_plugin_dispose(GObject *object)
{
  G_OBJECT_CLASS(desktop_webview_auth_plugin_parent_class)->dispose(object);
}

static void desktop_webview_auth_plugin_class_init(DesktopWebviewAuthPluginClass *klass)
{
  G_OBJECT_CLASS(klass)->dispose = desktop_webview_auth_plugin_dispose;
}

static void desktop_webview_auth_plugin_init(DesktopWebviewAuthPlugin *self) {}

static void method_call_cb(FlMethodChannel *channel, FlMethodCall *method_call,
                           gpointer user_data)
{
  desktop_webview_auth_plugin_handle_method_call(method_call, user_data);
}

void desktop_webview_auth_plugin_register_with_registrar(FlPluginRegistrar *registrar)
{
  DesktopWebviewAuthPlugin *self = DESKTOP_WEBVIEW_AUTH_PLUGIN(
      g_object_new(desktop_webview_auth_plugin_get_type(), nullptr));

  self->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();

  self->method_channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(self->registrar),
                            "io.invertase.flutter/desktop_webview_auth",
                            FL_METHOD_CODEC(codec));

  fl_method_channel_set_method_call_handler(self->method_channel, method_call_cb,
                                            g_object_ref(self),
                                            g_object_unref);

  g_object_unref(self);
}
