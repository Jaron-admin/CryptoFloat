#include "taskbar_layout.h"
#include <cstdio>
#include <limits>
int failures = 0;
void Check(bool ok, const char* name) {
  std::printf("%s %s\n", ok ? "PASS" : "FAIL", name);
  if (!ok) ++failures;
}
int main() {
  const auto compact = taskbar::CompactColumns({20, 100, 35}, 220, 6, 10);
  Check(compact == std::vector<int>({20, 100, 35}), "natural compact widths do not expand short cells");
  const auto clipped = taskbar::CompactColumns({20, 100, 35}, 100, 6, 10);
  Check(clipped.size() == 3 && clipped[0] == 20 && clipped[1] == 34 && clipped[2] == 34 &&
        clipped[0] + clipped[1] + clipped[2] + 12 == 100, "tight layout shrinks long columns without equal-width waste");
  const auto tiny = taskbar::CompactColumns({20, 100, 35}, 25, 6, 10);
  Check(tiny.size() == 1 && tiny[0] <= 25, "very narrow layout omits whole trailing columns safely");
  Check(taskbar::IsOwnProcess(GetCurrentProcessId()) && !taskbar::IsOwnProcess(0) &&
        !taskbar::IsOwnProcess(GetCurrentProcessId() + 1), "self-process exclusion rejects only helper elements");
  TaskbarFrame frame;
  Check(frame.transparent_background && frame.item_gap == 6, "taskbar surface defaults to transparent compact mode");
  frame.transparent_background = false; frame.item_gap = 13;
  frame.cells = {{L"CPU 23.5%", 0xFF00FF00, L"Processor usage"},
                 {L"内存 —", 0xFFFFFFFF, L"完整文字"}};
  Check(taskbar::ValidateFrame(frame), "valid bilingual frame accepted");
  std::vector<uint8_t> payload;
  TaskbarFrame decoded;
  Check(taskbar::EncodeFrame(frame, &payload) && taskbar::DecodeFrame(payload, &decoded) &&
        decoded.cells.size() == 2 && decoded.cells[1].text == L"内存 —" &&
        decoded.cells[0].tooltip == L"Processor usage" && decoded.width == 360 &&
        decoded.font_size == 11 && decoded.cells[0].color == 0xFF00FF00 &&
        !decoded.transparent_background && decoded.item_gap == 13,
        "frame roundtrip preserves text and styles");
  auto legacy = payload; legacy.resize(legacy.size() - 8);
  Check(taskbar::DecodeFrame(legacy, &decoded) && decoded.transparent_background && decoded.item_gap == 6,
        "legacy wire frame gets transparent compact defaults");
  frame.item_gap = 25;
  Check(!taskbar::ValidateFrame(frame), "wire gap is bounded");
  frame.item_gap = 6;
  frame.font_size = std::numeric_limits<double>::quiet_NaN();
  Check(!taskbar::ValidateFrame(frame), "reject NaN font");
  frame.font_size = std::numeric_limits<double>::infinity();
  Check(!taskbar::ValidateFrame(frame), "reject infinite font");
  frame.font_size = 11; frame.width = -1;
  Check(!taskbar::ValidateFrame(frame), "reject negative width");
  frame.width = 360; frame.cells[0].text.assign(2049, L'a');
  Check(!taskbar::EncodeFrame(frame, &payload), "reject oversized cell");
  frame.cells[0].text = L"CPU";
  Check(taskbar::EncodeFrame(frame, &payload), "encode valid packet payload");
  auto truncated = payload; if (!truncated.empty()) truncated.pop_back();
  Check(!taskbar::DecodeFrame(truncated, &decoded), "reject truncated payload");
  payload.push_back(0);
  Check(!taskbar::DecodeFrame(payload, &decoded), "reject trailing payload");
  payload.pop_back();
  std::vector<uint8_t> packet;
  Check(taskbar::EncodePacket(taskbar::PacketType::frame, payload, &packet), "encode envelope");
  if (packet.size() < 5) packet.assign(16, 0);
  std::vector<uint8_t> partial(packet.begin(), packet.begin() + 5);
  std::vector<taskbar::Packet> packets;
  Check(taskbar::ConsumePackets(&partial, &packets) && packets.empty() && partial.size() == 5,
        "partial envelope is retained");
  partial.insert(partial.end(), packet.begin() + 5, packet.end());
  Check(taskbar::ConsumePackets(&partial, &packets) && packets.size() == 1 && partial.empty(),
        "fragmented packet delivered once");
  packet[0] ^= 0x10; packets.clear();
  Check(!taskbar::ConsumePackets(&packet, &packets), "reject wrong protocol magic");
  Check(!taskbar::EncodePacket(taskbar::PacketType::frame,
        std::vector<uint8_t>(taskbar::kMaxPacket + 1), &packet), "reject oversized envelope");
  taskbar::EncodePacket(taskbar::PacketType::frame, payload, &packet);
  packet[12] = 255; packet[13] = 255; packet[14] = 255; packet[15] = 255;
  Check(!taskbar::ConsumePackets(&packet, &packets), "refuse oversized claimed length before allocation");
  frame.cells[0].text.assign(1, wchar_t{0xD800});
  Check(!taskbar::ValidateFrame(frame), "reject dangling UTF16 surrogate");
  frame.cells[0].text = L"CPU"; frame.cells.assign(33, frame.cells[0]);
  Check(!taskbar::ValidateFrame(frame), "reject excessive cell count");
  frame.cells.resize(32);
  for (auto& cell : frame.cells) { cell.text.assign(2048, L'x'); cell.tooltip.assign(4096, L'y'); }
  Check(!taskbar::ValidateFrame(frame), "aggregate frame bound prevents individually valid oversized fields");
  uint32_t code = 0;
  Check(!taskbar::DecodeCode({1, 0, 0}, 5, &code) &&
        !taskbar::DecodeCode({6, 0, 0, 0}, 5, &code), "malformed and unknown status codes rejected");
  taskbar::LayoutSnapshot layout{{0, 1000, 1920, 1048},
                               {{0, 1000, 560, 1048}, {1520, 1000, 1920, 1048}}, true, true, 96};
  auto fit = taskbar::FitFreeRegion(layout, 360, 32);
  Check(fit.status == taskbar::Status::displaying && fit.rect.left == 1152 &&
        fit.rect.right == 1512 && fit.rect.top == 1008, "fits padded true free region");
  auto compact_layout = layout;
  compact_layout.occupied = {{0, 1000, 1300, 1048}, {1520, 1000, 1920, 1048}};
  const auto compact_fit = taskbar::FitFreeRegion(compact_layout, 360, 32, 64);
  Check(compact_fit.status == taskbar::Status::displaying && compact_fit.rect.right - compact_fit.rect.left == 204,
        "compact display can shrink inside a verified narrower gap");
  compact_layout.occupied = {{0, 1000, 500, 1048}, {1000, 1000, 1380, 1048}, {1520, 1000, 1920, 1048}};
  const auto widest_fit = taskbar::FitFreeRegion(compact_layout, 360, 32, 64);
  Check(widest_fit.status == taskbar::Status::displaying && widest_fit.rect.right - widest_fit.rect.left == 360 && widest_fit.rect.right < 1000,
        "full text gap is preferred to a narrow gap further right");
  auto centered = layout;
  centered.alignment = taskbar::TaskbarAlignment::centered;
  centered.occupied = {{700, 1000, 1200, 1048}, {1520, 1000, 1920, 1048}};
  auto centered_fit = taskbar::FitFreeRegion(centered, 360, 32, 64);
  Check(centered_fit.status == taskbar::Status::displaying && centered_fit.rect.left == 8 &&
        centered_fit.rect.right == 368, "centered taskbar anchors data at far-left free edge rather than beside apps");
  centered.occupied.insert(centered.occupied.begin(), {0, 1000, 200, 1048});
  centered_fit = taskbar::FitFreeRegion(centered, 360, 32, 64);
  Check(centered_fit.status == taskbar::Status::displaying && centered_fit.rect.left == 208 &&
        centered_fit.rect.right == 568, "far-left placement avoids weather widgets with padding");
  centered.occupied = {{0, 1000, 400, 1048}, {600, 1000, 1100, 1048}, {1520, 1000, 1920, 1048}};
  centered_fit = taskbar::FitFreeRegion(centered, 360, 32, 64);
  Check(centered_fit.status == taskbar::Status::displaying && centered_fit.rect.left == 408 &&
        centered_fit.rect.right == 592, "centered taskbar compacts in far-left gap instead of choosing larger right gap");
  centered.occupied = {{0, 1000, 900, 1048}, {1520, 1000, 1920, 1048}};
  Check(taskbar::FitFreeRegion(centered, 360, 32, 64).status == taskbar::Status::noSpace,
        "centered taskbar does not cross midpoint or fall back right when left region is full");
  centered.occupied = {{0, 1000, 200, 1048}, {240, 1000, 340, 1048},
                       {700, 1000, 1200, 1048}, {1520, 1000, 1920, 1048}};
  centered_fit = taskbar::FitFreeRegion(centered, 360, 32, 64);
  Check(centered_fit.status == taskbar::Status::displaying && centered_fit.rect.left == 348 &&
        centered_fit.rect.right == 692, "left placement skips unusably narrow gaps without overlapping occupied controls");
  centered.alignment = taskbar::TaskbarAlignment::unknown;
  Check(taskbar::FitFreeRegion(centered, 360, 32, 64).status == taskbar::Status::waiting,
        "unknown taskbar alignment fails closed");
  centered.alignment = taskbar::TaskbarAlignment::centered;
  centered.bounds = {-2880, 1600, 0, 1684}; centered.dpi = 168;
  centered.occupied = {{-2880, 1600, -2600, 1684}, {-1800, 1600, -1000, 1684}, {-400, 1600, 0, 1684}};
  centered_fit = taskbar::FitFreeRegion(centered, 360, 32, 64);
  Check(centered_fit.status == taskbar::Status::displaying && centered_fit.rect.left == -2586 &&
        centered_fit.rect.right == -1956 && centered_fit.rect.top == 1614 && centered_fit.rect.bottom == 1670,
        "far-left placement scales padding and content on negative-coordinate high-DPI taskbar");
  layout.complete = false;
  Check(taskbar::FitFreeRegion(layout, 360, 32).status == taskbar::Status::waiting,
        "unknown layout refused");
  layout.complete = true; layout.visible = false;
  Check(taskbar::FitFreeRegion(layout, 360, 32).status == taskbar::Status::waiting,
        "auto-hidden layout refused");
  layout.visible = true; layout.occupied.push_back({560, 1000, 1520, 1048});
  Check(taskbar::FitFreeRegion(layout, 360, 32).status == taskbar::Status::noSpace,
        "no room refused");
  layout.bounds = {0, 0, 48, 1080};
  Check(taskbar::FitFreeRegion(layout, 360, 32).status == taskbar::Status::unsupported,
        "vertical taskbar refused");
  layout = {{-1920, 1000, 0, 1072}, {{-1920, 1000, -1600, 1072}, {-600, 1000, 0, 1072}}, true, true, 144};
  fit = taskbar::FitFreeRegion(layout, 360, 32);
  Check(fit.status == taskbar::Status::displaying && fit.rect.right == -612 &&
        fit.rect.left == -1152 && fit.rect.bottom - fit.rect.top == 48,
        "DPI scales physical fit on negative coordinates");
  layout.occupied.clear();
  Check(taskbar::FitFreeRegion(layout, 360, 32).status == taskbar::Status::waiting,
        "empty control evidence does not establish free space");
  layout.occupied = {{-1800, 1000, -1500, 1072}, {-1500, 1000, -500, 1072}};
  Check(taskbar::FitFreeRegion(layout, 360, 32).status == taskbar::Status::noSpace,
        "adjacent occupied regions leave no false gap");
  SetLastError(ERROR_ACCESS_DENIED);
  taskbar::WriteDiagnostic(taskbar::DiagnosticSource::bridge, "test=preservesWin32Error");
  Check(GetLastError() == ERROR_ACCESS_DENIED, "diagnostics preserve caller Win32 error");
  for (int i = 0; i < 100; ++i)
    taskbar::WriteDiagnostic(taskbar::DiagnosticSource::bridge, "test=rotation " + std::string(2000, 'x'));
  wchar_t module[32768]{}; GetModuleFileNameW(nullptr, module, 32768);
  std::wstring log_path(module); log_path.resize(log_path.find_last_of(L"\\/") + 1);
  log_path += L"user_data\\taskbar-bridge.log";
  WIN32_FILE_ATTRIBUTE_DATA current_log{}, previous_log{};
  Check(GetFileAttributesExW(log_path.c_str(), GetFileExInfoStandard, &current_log) &&
        GetFileAttributesExW((log_path + L".1").c_str(), GetFileExInfoStandard, &previous_log) &&
        current_log.nFileSizeHigh == 0 && current_log.nFileSizeLow <= 64 * 1024 &&
        previous_log.nFileSizeHigh == 0 && previous_log.nFileSizeLow <= 64 * 1024,
        "diagnostics rotate into one bounded 64 KiB backup");
  return failures == 0 ? 0 : 1;
}
