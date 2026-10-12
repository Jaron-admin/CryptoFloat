#ifndef RUNNER_PLATFORM_CHANNEL_H_
#define RUNNER_PLATFORM_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>

#include "win32_window.h"

class NotificationTray;
class SystemProxy;
class ContextMenu;

// The only boundary between portable Dart code and Windows desktop services.
class PlatformChannel {
 public:
  PlatformChannel(Win32Window* window, flutter::BinaryMessenger* messenger);
  ~PlatformChannel();

  // Native callbacks must reach their owners before Flutter plugin routing.
  bool HandleWindowMessage(UINT message, WPARAM wparam, LPARAM lparam,
                            LRESULT* result);

 private:
  void HandleMethod(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  Win32Window* window_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::unique_ptr<NotificationTray> tray_;
  std::unique_ptr<SystemProxy> system_proxy_;
  std::shared_ptr<ContextMenu> context_menu_;
};

#endif  // RUNNER_PLATFORM_CHANNEL_H_
