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
  FlPluginRegistrar* registrar;
  FlMethodChannel* method_channel;
  gchar *redirectUri;
  gchar *callbackUri;
  GtkWidget *popupWindow;
} plugin;

G_DEFINE_TYPE(DesktopWebviewAuthPlugin, desktop_webview_auth_plugin, g_object_get_type())

static void changed (WebKitWebView *view, WebKitLoadEvent event, gpointer user_data)
{
  DesktopWebviewAuthPlugin* plugin = DESKTOP_WEBVIEW_AUTH_PLUGIN(user_data);

  const gchar *uri = webkit_web_view_get_uri (view);
  const gchar *redirectUri = plugin->redirectUri;

  char str[(int) strlen(redirectUri)];
  const gchar *copy = strncpy(str, (char*) uri, (int) strlen(redirectUri));

  bool matching = strcmp(copy, redirectUri);

  g_print("%s \n", copy);

  g_print (
    "======================= redirectUri ======================= \n length:%d content: %s matching? %s\n",
    (int) strlen(redirectUri),
    redirectUri,
    matching == 1? "False" : "True"
  );
  
  if(event == WEBKIT_LOAD_REDIRECTED && matching) {
    g_free (plugin->redirectUri);

    g_print("callback url: %s\n", webkit_web_view_get_uri (view));
    const gchar *callbackUri = (gchar*) webkit_web_view_get_uri (view);

    g_autoptr(FlValue) result = fl_value_new_string(callbackUri);

    //response = FL_METHOD_RESPONSE(fl_method_success_response_new(value));

    fl_method_channel_invoke_method(plugin->method_channel, "callbackUri",
                                    result, nullptr, nullptr, plugin);

    gtk_window_close (GTK_WINDOW(plugin->popupWindow));
  }
}

// Called when a method call is received from Flutter.
static void desktop_webview_auth_plugin_handle_method_call(
    GtkWidget *window, FlMethodCall *method_call)
{
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar *method = fl_method_call_get_name(method_call);
  FlValue *args = fl_method_call_get_args(method_call);

  if (strcmp(method, "signIn") == 0)
  {    
    GtkWidget *popup = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_transient_for(GTK_WINDOW(popup), GTK_WINDOW(window));

    GtkWidget *scrollview = gtk_scrolled_window_new(nullptr, nullptr);
    GtkWidget *webview = webkit_web_view_new();
    gtk_container_add(GTK_CONTAINER(scrollview), webview);
    gtk_container_add(GTK_CONTAINER(popup), scrollview);

    FlValue *signInUriValue = fl_value_lookup_string(args, "signInUri");
    const gchar *signInUri = fl_value_get_string(signInUriValue);

    FlValue *redirectUriValue = fl_value_lookup_string(args, "redirectUri");
    const gchar *redirectUri = fl_value_get_string(redirectUriValue);

    webkit_web_view_load_uri(WEBKIT_WEB_VIEW(webview), signInUri);

    gtk_window_set_position(GTK_WINDOW(popup), GTK_WIN_POS_MOUSE);
    gtk_window_set_default_size(GTK_WINDOW(popup), 980, 720);

    plugin.redirectUri = g_strdup (redirectUri);
    plugin.popupWindow = popup;

    g_signal_connect(G_OBJECT (webview), "load-changed", G_CALLBACK (changed), &plugin);

    gtk_widget_show_all(popup);
  }
  else
  {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
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
  GtkWidget *window = GTK_WIDGET(user_data);
  desktop_webview_auth_plugin_handle_method_call(window, method_call);
}

void desktop_webview_auth_plugin_register_with_registrar(FlPluginRegistrar *registrar)
{
  DesktopWebviewAuthPlugin *plugin = DESKTOP_WEBVIEW_AUTH_PLUGIN(
      g_object_new(desktop_webview_auth_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) method_channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "io.invertase.flutter/desktop_webview_auth",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(method_channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  plugin->method_channel = g_object_ref(method_channel);

}
