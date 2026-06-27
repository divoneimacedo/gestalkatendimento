#include "include/videosdk_linux_shim/videosdk_linux_shim_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <sys/utsname.h>

#include <cstring>

#define VIDEO_SDK_LINUX_SHIM_PLUGIN(obj)                                      \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), videosdk_linux_shim_plugin_get_type(),    \
                              VideosdkLinuxShimPlugin))

struct _VideosdkLinuxShimPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(VideosdkLinuxShimPlugin,
              videosdk_linux_shim_plugin,
              g_object_get_type())

static gchar* get_linux_version() {
  struct utsname info;
  if (uname(&info) == 0) {
    return g_strdup_printf("%s %s", info.sysname, info.release);
  }

  return g_strdup("Linux");
}

static FlValue* get_device_info() {
  g_autofree gchar* version = get_linux_version();
  FlValue* info = fl_value_new_map();
  fl_value_set_string_take(info, "brand", fl_value_new_string("Linux"));
  fl_value_set_string_take(info, "model", fl_value_new_string("Desktop"));
  fl_value_set_string_take(info, "osVersion", fl_value_new_string(version));
  return info;
}

static void videosdk_linux_shim_plugin_handle_method_call(
    VideosdkLinuxShimPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    g_autofree gchar* version = get_linux_version();
    response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_string(version)));
  } else if (strcmp(method, "getDeviceInfo") == 0) {
    response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(get_device_info()));
  } else if (strcmp(method, "getCpuUsage") == 0 ||
             strcmp(method, "getMemoryUsage") == 0) {
    response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_float(0)));
  } else if (strcmp(method, "requestScreenSharePermission") == 0 ||
             strcmp(method, "processorMethod") == 0) {
    response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void method_call_cb(FlMethodChannel* channel,
                           FlMethodCall* method_call,
                           gpointer user_data) {
  VideosdkLinuxShimPlugin* plugin = VIDEO_SDK_LINUX_SHIM_PLUGIN(user_data);
  videosdk_linux_shim_plugin_handle_method_call(plugin, method_call);
}

static void videosdk_linux_shim_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(videosdk_linux_shim_plugin_parent_class)->dispose(object);
}

static void videosdk_linux_shim_plugin_class_init(
    VideosdkLinuxShimPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = videosdk_linux_shim_plugin_dispose;
}

static void videosdk_linux_shim_plugin_init(VideosdkLinuxShimPlugin* self) {}

void videosdk_linux_shim_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  VideosdkLinuxShimPlugin* plugin = VIDEO_SDK_LINUX_SHIM_PLUGIN(
      g_object_new(videosdk_linux_shim_plugin_get_type(), nullptr));

  FlBinaryMessenger* messenger = fl_plugin_registrar_get_messenger(registrar);

  g_autoptr(FlStandardMethodCodec) method_codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) method_channel =
      fl_method_channel_new(messenger, "videosdk", FL_METHOD_CODEC(method_codec));
  fl_method_channel_set_method_call_handler(
      method_channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  g_autoptr(FlStandardMethodCodec) event_codec = fl_standard_method_codec_new();
  fl_event_channel_new(
      messenger, "videosdk-event", FL_METHOD_CODEC(event_codec));

  g_object_unref(plugin);
}
