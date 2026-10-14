#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "dpi_diagnostics.h"
#include "single_instance.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  const auto command_line_arguments = GetCommandLineArguments();
  const auto diagnostics = DpiDiagnostics::ParseArguments(command_line_arguments);
  // An explicitly isolated probe never activates an already running real app.
  SingleInstance single_instance(diagnostics.isolated
      ? L"DuoMonitor.DpiProbe.v1." + std::to_wstring(GetCurrentProcessId())
      : L"CryptoFloat.SingleInstance.v1");
  const auto instance_result = single_instance.Start();
  if (instance_result == SingleInstance::StartResult::kForwarded) {
    return EXIT_SUCCESS;
  }
  if (instance_result == SingleInstance::StartResult::kError) {
    const bool chinese = PRIMARYLANGID(GetUserDefaultUILanguage()) == LANG_CHINESE;
    MessageBoxW(
        nullptr,
        chinese ? L"无法启动或唤回 DuoMonitor。请先退出已运行的 DuoMonitor，再重试。"
                : L"DuoMonitor could not start or activate the running app. "
                  L"Close any running DuoMonitor instance and try again.",
        L"DuoMonitor", MB_OK | MB_ICONERROR);
    return EXIT_FAILURE;
  }
  DpiDiagnostics::Process().InitializeForProcess(diagnostics.enabled);

  // Console support belongs to development builds. A release opens only the panel.
#ifndef NDEBUG
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }
#endif

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(command_line_arguments);

  FlutterWindow window(project, single_instance);
  Win32Window::Point origin(40, 40);
  Win32Window::Size size(460, 360);
  if (!window.Create(L"DuoMonitor", origin, size, diagnostics)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
