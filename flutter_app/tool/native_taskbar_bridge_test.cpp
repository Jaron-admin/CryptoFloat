#include "taskbar_host.h"
#include <cstdio>
#include <limits>
int main() {
  const auto start = GetTickCount64();
  bool displayed = false, no_space = false, disabled = false, invalid = false;
  {
    TaskbarHost host(nullptr); TaskbarFrame frame;
    frame.cells = {{L"CPU 25%", 0xFFFFFFFF, L"CPU usage"}};
    auto deadline = GetTickCount64() + 5000;
    while (GetTickCount64() < deadline && !displayed) {
      displayed = host.Update(frame) == "displaying"; Sleep(20);
    }
    // Width is now a maximum, so short content remains compact even at 1600.
    // A two-row 32px font really cannot fit the fixture's 48px taskbar.
    frame.width = 1600; frame.font_size = 32; deadline = GetTickCount64() + 1500;
    while (GetTickCount64() < deadline && !no_space) {
      no_space = host.Update(frame) == "noSpace"; Sleep(20);
    }
    frame.enabled = false; disabled = host.Update(frame) == "disabled";
    frame.font_size = std::numeric_limits<double>::quiet_NaN(); invalid = host.Update(frame) == "error";
  }
  bool bounded = GetTickCount64() - start < 9000;
  std::printf("%s bridge receives helper display state\n", displayed ? "PASS" : "FAIL");
  std::printf("%s changed frame is delivered and oversized height reports noSpace\n", no_space ? "PASS" : "FAIL");
  std::printf("%s disabled update returns immediately\n", disabled ? "PASS" : "FAIL");
  std::printf("%s nonfinite bridge input refused\n", invalid ? "PASS" : "FAIL");
  std::printf("%s bridge lifetime is bounded\n", bounded ? "PASS" : "FAIL");
  return displayed && no_space && disabled && invalid && bounded ? 0 : 1;
}
