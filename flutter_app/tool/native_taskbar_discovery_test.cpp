#define TASKBAR_ISOLATED_TEST
#define TASKBAR_TEST_DISCOVERY_DELAY_MS 1200
#include "../windows/runner/taskbar_main.cpp"
#include <cstdio>
int main() {
  Host host;
  host.stop = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  host.fake_bar = CreateWindowExW(WS_EX_TOOLWINDOW, L"STATIC", L"Delayed discovery fixture",
      WS_POPUP, 0, 0, 1200, 48, nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
  if (!host.stop || !host.fake_bar) return 2;
  WNDCLASSW display{}; display.hInstance = GetModuleHandleW(nullptr);
  display.lpfnWndProc = DisplayProc; display.lpszClassName = kDisplayClass;
  RegisterClassW(&display);
  host.incoming_frame.cells = {{L"CPU 25%", 0xFFFFFFFF, L"Processor"}};
  host.revision = 1;
  std::thread discovery([&host] { host.DiscoveryLoop(); });
  const auto deadline = GetTickCount64() + 4000;
  bool published = false;
  while (!published && GetTickCount64() < deadline) {
    { std::lock_guard<std::mutex> lock(host.mutex); published = host.snapshot_time != 0; }
    Sleep(10);
  }
  SetEvent(host.stop); discovery.join();
  bool aged = published && GetTickCount64() - host.snapshot_time >= 1200;
  host.Tick();
  bool refused = host.status == taskbar::Status::waiting && host.display == nullptr;
  std::printf("%s shared discovery preserves acquisition start across delayed traversal\n", aged ? "PASS" : "FAIL");
  std::printf("%s completed stale discovery cannot attach despite unchanged outer bounds\n", refused ? "PASS" : "FAIL");
  // A new occupied control fills the old apparent gap without changing bar bounds.
  host.snapshot.occupied.push_back({400, 0, 1000, 48});
  host.snapshot_time = GetTickCount64(); host.Tick();
  bool occupied = host.status == taskbar::Status::noSpace && host.display == nullptr;
  std::printf("%s fresh occupied geometry refuses the former free region\n", occupied ? "PASS" : "FAIL");
  host.snapshot.occupied.pop_back(); host.snapshot_time = GetTickCount64(); host.Tick();
  bool recovered = host.status == taskbar::Status::displaying && host.display != nullptr;
  std::printf("%s timely free geometry recovers after stale discovery\n", recovered ? "PASS" : "FAIL");
  wchar_t module[32768]{}; GetModuleFileNameW(nullptr, module, 32768);
  std::wstring log_path(module); log_path.resize(log_path.find_last_of(L"\\/") + 1);
  log_path += L"user_data\\taskbar-helper.log";
  WIN32_FILE_ATTRIBUTE_DATA before{}, after{};
  bool logged = GetFileAttributesExW(log_path.c_str(), GetFileExInfoStandard, &before) != FALSE;
  for (int i = 0; i < 10; ++i) host.Tick();
  bool quiet = logged && GetFileAttributesExW(log_path.c_str(), GetFileExInfoStandard, &after) &&
      before.nFileSizeLow == after.nFileSizeLow && before.nFileSizeHigh == after.nFileSizeHigh;
  std::printf("%s unchanged display state does not repeat diagnostic log entries\n", quiet ? "PASS" : "FAIL");
  host.RemoveDisplay();
  if (host.text_font) DeleteObject(host.text_font);
  if (host.number_font) DeleteObject(host.number_font);
  DestroyWindow(host.fake_bar); CloseHandle(host.stop);
  return aged && refused && occupied && recovered && quiet ? 0 : 1;
}
