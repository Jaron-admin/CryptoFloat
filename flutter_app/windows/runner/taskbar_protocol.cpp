#include "taskbar_protocol.h"
#include "storage_paths.h"
#include <cmath>
#include <cstring>
#include <cstdio>
#include <mutex>
namespace taskbar {
namespace {
constexpr uint32_t kMagic = 0x4854504D;  // MPTH, little endian.
void Put(std::vector<uint8_t>* out, uint32_t v) {
  for (int i = 0; i < 4; ++i) out->push_back(static_cast<uint8_t>(v >> (8 * i)));
}
uint32_t Get(const uint8_t* p) {
  return static_cast<uint32_t>(p[0]) | (static_cast<uint32_t>(p[1]) << 8) |
         (static_cast<uint32_t>(p[2]) << 16) | (static_cast<uint32_t>(p[3]) << 24);
}
bool TextValid(const std::wstring& text, size_t limit, bool empty = true) {
  if (text.size() > limit || (!empty && text.empty())) return false;
  for (size_t i = 0; i < text.size(); ++i) {
    const auto c = static_cast<uint16_t>(text[i]);
    if (c == 0) return false;
    if (c >= 0xD800 && c <= 0xDBFF) {
      if (++i == text.size() || text[i] < 0xDC00 || text[i] > 0xDFFF) return false;
    } else if (c >= 0xDC00 && c <= 0xDFFF) return false;
  }
  return true;
}
void PutText(std::vector<uint8_t>* out, const std::wstring& text) {
  Put(out, static_cast<uint32_t>(text.size()));
  for (wchar_t c : text) {
    out->push_back(static_cast<uint8_t>(c)); out->push_back(static_cast<uint8_t>(c >> 8));
  }
}
struct Reader {
  const std::vector<uint8_t>& bytes; size_t pos = 0;
  bool Number(uint32_t* out) {
    if (bytes.size() - pos < 4) return false;
    *out = Get(bytes.data() + pos); pos += 4; return true;
  }
  bool Text(std::wstring* out, size_t limit) {
    uint32_t count = 0;
    if (!Number(&count) || count > limit || count > (bytes.size() - pos) / 2) return false;
    out->clear(); out->reserve(count);
    for (uint32_t i = 0; i < count; ++i) {
      out->push_back(static_cast<wchar_t>(bytes[pos] | (bytes[pos + 1] << 8))); pos += 2;
    }
    return true;
  }
};
}
void WriteDiagnostic(DiagnosticSource source, const std::string& message) {
  // Diagnostics must not change callers' Win32 failure details.
  const DWORD previous_error = GetLastError();
  static std::mutex log_mutex;
  std::lock_guard<std::mutex> lock(log_mutex);
  auto write = [&] {
    const auto root = storage_paths::ForProcess();
    if (root.empty()) return;
    std::error_code directory_error;
    std::filesystem::create_directories(root, directory_error);
    if (directory_error) return;
    const auto directory = root.wstring();
    const std::wstring path = directory + (source == DiagnosticSource::bridge ?
        L"\\taskbar-bridge.log" : L"\\taskbar-helper.log");
    SYSTEMTIME now{}; GetSystemTime(&now);
    char prefix[40]{};
    std::snprintf(prefix, sizeof(prefix), "%04u-%02u-%02uT%02u:%02u:%02uZ ",
        now.wYear, now.wMonth, now.wDay, now.wHour, now.wMinute, now.wSecond);
    std::string record(prefix);
    for (const char ch : message.substr(0, 768)) record += ch >= 32 && ch <= 126 ? ch : '?';
    record += "\r\n";
    WIN32_FILE_ATTRIBUTE_DATA attributes{};
    if (GetFileAttributesExW(path.c_str(), GetFileExInfoStandard, &attributes) &&
        (attributes.nFileSizeHigh != 0 || attributes.nFileSizeLow > 64 * 1024 - record.size())) {
      if (!MoveFileExW(path.c_str(), (path + L".1").c_str(), MOVEFILE_REPLACE_EXISTING)) return;
    }
    HANDLE file = CreateFileW(path.c_str(), FILE_APPEND_DATA, FILE_SHARE_READ,
        nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) return;
    DWORD written = 0;
    WriteFile(file, record.data(), static_cast<DWORD>(record.size()), &written, nullptr);
    CloseHandle(file);
  };
  write(); SetLastError(previous_error);
}
bool ValidateFrame(const TaskbarFrame& f) {
  if (f.width < 64 || f.width > 1600 || (f.line_count != 1 && f.line_count != 2) ||
      !std::isfinite(f.font_size) || f.font_size < 6 || f.font_size > 32 ||
      !TextValid(f.font_family, 128, false) || !TextValid(f.number_font_family, 128, false) ||
      f.cells.size() > 256 || f.item_gap < 0 || f.item_gap > 24 ||
      f.label_value_gap < 0 || f.label_value_gap > 24 ||
      f.carousel_interval_seconds < 2 || f.carousel_interval_seconds > 60) return false;
  size_t size = 68 + 2 * (f.font_family.size() + f.number_font_family.size());
  for (const auto& cell : f.cells) {
    if (!TextValid(cell.text, 2048) || !TextValid(cell.tooltip, 4096) ||
        !TextValid(cell.label, 2048) || !TextValid(cell.value, 2048) || !TextValid(cell.suffix, 2048)) return false;
    size += 32 + 2 * (cell.text.size() + cell.tooltip.size() + cell.label.size() + cell.value.size() + cell.suffix.size());
  }
  return size <= kMaxPacket - 16;
}
bool EncodeFrame(const TaskbarFrame& f, std::vector<uint8_t>* out) {
  if (!out || !ValidateFrame(f)) return false;
  out->clear(); Put(out, f.enabled ? 1 : 0); Put(out, f.chinese ? 1 : 0);
  Put(out, static_cast<uint32_t>(f.width)); Put(out, static_cast<uint32_t>(f.line_count));
  uint64_t bits; std::memcpy(&bits, &f.font_size, sizeof(bits));
  Put(out, static_cast<uint32_t>(bits)); Put(out, static_cast<uint32_t>(bits >> 32));
  Put(out, f.background); Put(out, f.foreground);
  PutText(out, f.font_family); PutText(out, f.number_font_family);
  Put(out, static_cast<uint32_t>(f.cells.size()));
  for (const auto& cell : f.cells) { Put(out, cell.color); PutText(out, cell.text); PutText(out, cell.tooltip); }
  Put(out, f.transparent_background ? 1 : 0); Put(out, static_cast<uint32_t>(f.item_gap));
  Put(out, static_cast<uint32_t>(f.label_value_gap)); Put(out, f.auto_carousel ? 1 : 0);
  Put(out, static_cast<uint32_t>(f.carousel_interval_seconds)); Put(out, static_cast<uint32_t>(f.cells.size()));
  for (const auto& cell : f.cells) {
    Put(out, cell.segmented ? 1 : 0); PutText(out, cell.label); PutText(out, cell.value);
    PutText(out, cell.suffix); Put(out, cell.suffix_color);
  }
  return true;
}
bool DecodeFrame(const std::vector<uint8_t>& bytes, TaskbarFrame* out) {
  if (!out || bytes.size() > kMaxPacket - 16) return false;
  Reader r{bytes}; TaskbarFrame f; uint32_t enabled, chinese, width, rows, lo, hi, count;
  if (!r.Number(&enabled) || enabled > 1 || !r.Number(&chinese) || chinese > 1 ||
      !r.Number(&width) || !r.Number(&rows) || !r.Number(&lo) || !r.Number(&hi) ||
      !r.Number(&f.background) || !r.Number(&f.foreground) ||
      !r.Text(&f.font_family, 128) || !r.Text(&f.number_font_family, 128) ||
      !r.Number(&count) || count > 256 || width > 1600 || rows > 2) return false;
  f.enabled = enabled == 1; f.chinese = chinese == 1;
  f.width = static_cast<int>(width); f.line_count = static_cast<int>(rows);
  uint64_t bits = lo | (static_cast<uint64_t>(hi) << 32);
  std::memcpy(&f.font_size, &bits, sizeof(bits));
  for (uint32_t i = 0; i < count; ++i) {
    TaskbarCell cell;
    if (!r.Number(&cell.color) || !r.Text(&cell.text, 2048) || !r.Text(&cell.tooltip, 4096)) return false;
    f.cells.push_back(std::move(cell));
  }
  // Legacy frames omit this fixed extension and receive the current defaults.
  if (r.pos != bytes.size()) {
    uint32_t transparent, gap;
    if (!r.Number(&transparent) || transparent > 1 || !r.Number(&gap) || gap > 24) return false;
    f.transparent_background = transparent == 1; f.item_gap = static_cast<int>(gap);
  }
  if (r.pos != bytes.size()) {
    uint32_t gap, automatic, interval, segmented_count;
    if (!r.Number(&gap) || gap > 24 || !r.Number(&automatic) || automatic > 1 ||
        !r.Number(&interval) || interval < 2 || interval > 60 ||
        !r.Number(&segmented_count) || segmented_count != count) return false;
    f.label_value_gap = static_cast<int>(gap); f.auto_carousel = automatic == 1;
    f.carousel_interval_seconds = static_cast<int>(interval);
    for (auto& cell : f.cells) {
      uint32_t segmented;
      if (!r.Number(&segmented) || segmented > 1 || !r.Text(&cell.label, 2048) ||
          !r.Text(&cell.value, 2048) || !r.Text(&cell.suffix, 2048) || !r.Number(&cell.suffix_color)) return false;
      cell.segmented = segmented == 1;
    }
  }
  if (r.pos != bytes.size() || !ValidateFrame(f)) return false;
  *out = std::move(f); return true;
}
bool EncodePacket(PacketType type, const std::vector<uint8_t>& payload, std::vector<uint8_t>* out) {
  const auto code = static_cast<uint32_t>(type);
  if (!out || code < 1 || code > 3 || payload.size() > kMaxPacket - 16) return false;
  out->clear(); Put(out, kMagic); Put(out, 1); Put(out, code); Put(out, static_cast<uint32_t>(payload.size()));
  out->insert(out->end(), payload.begin(), payload.end()); return true;
}
bool ConsumePackets(std::vector<uint8_t>* buffer, std::vector<Packet>* out) {
  if (!buffer || !out || buffer->size() > kMaxPacket * 2) return false;
  size_t pos = 0;
  while (buffer->size() - pos >= 16) {
    const auto* p = buffer->data() + pos;
    uint32_t type = Get(p + 8), size = Get(p + 12);
    if (Get(p) != kMagic || Get(p + 4) != 1 || type < 1 || type > 3 || size > kMaxPacket - 16) return false;
    if (buffer->size() - pos < 16 + size) break;
    out->push_back({static_cast<PacketType>(type), {p + 16, p + 16 + size}}); pos += 16 + size;
    if (out->size() > 128) return false;
  }
  buffer->erase(buffer->begin(), buffer->begin() + static_cast<std::ptrdiff_t>(pos)); return true;
}
std::vector<uint8_t> EncodeCode(uint32_t code) { std::vector<uint8_t> out; Put(&out, code); return out; }
bool DecodeCode(const std::vector<uint8_t>& payload, uint32_t maximum, uint32_t* code) {
  if (!code || payload.size() != 4) return false;
  *code = Get(payload.data()); return *code <= maximum;
}
const char* StatusName(Status s) {
  static const char* names[] = {"disabled", "displaying", "waiting", "noSpace", "unsupported", "error"};
  auto i = static_cast<uint32_t>(s); return i < 6 ? names[i] : "error";
}
const char* ActionName(Action a) {
  static const char* names[] = {"", "show", "settings", "refresh", "disable", "exit"};
  auto i = static_cast<uint32_t>(a); return i < 6 ? names[i] : "";
}
bool ReadPipeAvailable(HANDLE pipe, std::vector<uint8_t>* buffer, std::vector<Packet>* packets) {
  DWORD available = 0;
  if (!PeekNamedPipe(pipe, nullptr, 0, nullptr, &available, nullptr)) return false;
  if (available != 0) {
    uint8_t chunk[4096]; DWORD read = 0;
    if (!ReadFile(pipe, chunk, (std::min)(available, DWORD{4096}), &read, nullptr) || read == 0) return false;
    buffer->insert(buffer->end(), chunk, chunk + read);
  }
  return ConsumePackets(buffer, packets);
}
bool WritePacket(HANDLE pipe, PacketType type, const std::vector<uint8_t>& payload) {
  std::vector<uint8_t> packet;
  if (!EncodePacket(type, payload, &packet)) return false;
  size_t offset = 0;
  while (offset < packet.size()) {
    DWORD written = 0;
    if (!WriteFile(pipe, packet.data() + offset, static_cast<DWORD>(packet.size() - offset), &written, nullptr) || written == 0) return false;
    offset += written;
  }
  return true;
}
}
