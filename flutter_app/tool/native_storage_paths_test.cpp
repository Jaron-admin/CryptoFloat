#include "taskbar_protocol.h"
#include <filesystem>
#include <fstream>
#include <iostream>

int main() {
  wchar_t executable[32768]{};
  GetModuleFileNameW(nullptr, executable, 32768);
  const auto app = std::filesystem::path(executable).parent_path();
  const auto profile = app / "storage-test-profile";
  const auto marker = app / "duomonitor_storage.json";
  SetEnvironmentVariableW(L"APPDATA", profile.c_str());
  { std::ofstream stream(marker); stream << "{\"mode\":\"system\"}\n"; }
  taskbar::WriteDiagnostic(taskbar::DiagnosticSource::bridge, "storage routing test");
  const bool correct = std::filesystem::exists(profile / "DuoMonitor" / "taskbar-bridge.log");
  std::filesystem::remove(marker);
  if (!correct) { std::cerr << "System mode diagnostics were not routed into the system data directory.\n"; return 1; }
  std::cout << "System storage diagnostics routing passed.\n";
  return 0;
}
