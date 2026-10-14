#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "single_instance.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project,
                             SingleInstance& single_instance)
    : project_(project), single_instance_(single_instance) {}

FlutterWindow::~FlutterWindow() {
  // The Win32Window base destructor runs after these members are destroyed.
  // Detach the native activation callback while this derived object is alive.
  single_instance_.DetachWindow();
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  platform_channel_ = std::make_unique<PlatformChannel>(
      this, flutter_controller_->engine()->messenger());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return single_instance_.AttachWindow(GetHandle());
}

void FlutterWindow::OnDestroy() {
  single_instance_.DetachWindow();
  platform_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == SingleInstance::ActivationMessage()) {
    // Restore the current view, including an unsaved settings draft. This mirrors
    // the tray's restore path without depending on a Dart event subscription.
    ClampToVisibleWorkArea();
    ::ShowWindow(hwnd, IsIconic(hwnd) ? SW_RESTORE : SW_SHOW);
    SetForegroundWindow(hwnd);
    return 0;
  }
  LRESULT native_result = 0;
  if (platform_channel_ &&
      platform_channel_->HandleWindowMessage(message, wparam, lparam, &native_result)) {
    return native_result;
  }
  // Frameless geometry belongs to this host, including where Flutter fills it.
  if (message == WM_NCCALCSIZE || message == WM_NCHITTEST ||
      message == WM_GETMINMAXINFO || message == WM_GETDPISCALEDSIZE ||
      message == WM_SIZING) {
    return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      if (flutter_controller_) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
