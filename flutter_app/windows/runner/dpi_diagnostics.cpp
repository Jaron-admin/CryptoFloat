#include "dpi_diagnostics.h"

#include <algorithm>
#include <cmath>
#include <fstream>
#include <iomanip>
#include <locale>
#include <sstream>
#include <string_view>

namespace {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
constexpr uintmax_t kMaximumBytes = 64 * 1024;
const Value* Find(const Map& map, const char* key) {
  const auto found = map.find(Value(key));
  return found == map.end() ? nullptr : &found->second;
}
bool Number(const Value* value, double low, double high, double* output) {
  if (!value) return false;
  if (const auto floating = std::get_if<double>(value)) *output = *floating;
  else if (const auto integer32 = std::get_if<int32_t>(value)) *output = *integer32;
  else if (const auto integer64 = std::get_if<int64_t>(value)) {
    *output = static_cast<double>(*integer64);
  } else return false;
  return std::isfinite(*output) && *output >= low && *output <= high;
}
bool Integer(const Value* value, int64_t maximum, int64_t* output) {
  if (!value) return false;
  if (const auto integer32 = std::get_if<int32_t>(value)) *output = *integer32;
  else if (const auto integer64 = std::get_if<int64_t>(value)) *output = *integer64;
  else return false;
  return *output >= 0 && *output <= maximum;
}
const char* NativeName(DpiNativeEvent event) {
  switch (event) {
    case DpiNativeEvent::kParentDpi: return "parentDpi";
    case DpiNativeEvent::kParentSize: return "parentSize";
    case DpiNativeEvent::kEnterMove: return "enterMove";
    case DpiNativeEvent::kExitMove: return "exitMove";
    case DpiNativeEvent::kWindowPosition: return "windowPosition";
    case DpiNativeEvent::kChildBeforeParent: return "childBeforeParent";
    case DpiNativeEvent::kChildAfterParent: return "childAfterParent";
    case DpiNativeEvent::kChildSize: return "childSize";
    case DpiNativeEvent::kMouseDown: return "mouseDown";
  }
  return nullptr;
}
uint64_t TimestampMicros() {
  LARGE_INTEGER now{}, frequency{};
  if (!QueryPerformanceCounter(&now) || !QueryPerformanceFrequency(&frequency) ||
      frequency.QuadPart <= 0) return GetTickCount64() * 1000;
  return static_cast<uint64_t>(
      static_cast<double>(now.QuadPart) * 1000000.0 / frequency.QuadPart);
}
void Rectangle(std::ostream& stream, const char* prefix, const RECT& rect) {
  stream << ",\"" << prefix << "X\":" << rect.left
         << ",\"" << prefix << "Y\":" << rect.top
         << ",\"" << prefix << "Width\":" << rect.right - rect.left
         << ",\"" << prefix << "Height\":" << rect.bottom - rect.top;
}
}  // namespace

DpiDiagnostics::Options DpiDiagnostics::ParseArguments(
    const std::vector<std::string>& arguments) {
  Options options;
  options.enabled = std::find(arguments.begin(), arguments.end(),
      "--dpi-diagnostics") != arguments.end();
  options.isolated = options.enabled && std::find(arguments.begin(),
      arguments.end(), "--dpi-probe-isolated") != arguments.end();
  return options;
}

DpiDiagnostics& DpiDiagnostics::Process() {
  static DpiDiagnostics instance;
  return instance;
}

void DpiDiagnostics::Initialize(bool enabled,
                                const std::filesystem::path& directory) {
  std::lock_guard<std::mutex> lock(mutex_);
  enabled_ = false;
  file_.clear();
  sequence_ = 0;
  render_deadline_millis_ = 0;
  render_transition_ = 0;
  resize_samples_remaining_ = 0;
  child_paint_count_ = 0;
  child_erase_count_ = 0;
  if (!enabled) return;
  try {
    std::error_code error;
    std::filesystem::create_directories(directory, error);
    if (error) return;
    file_ = directory / "dpi-diagnostics.log";
    enabled_ = true;
  } catch (...) {
    // Diagnostics must not prevent normal application operation.
  }
}

void DpiDiagnostics::InitializeForProcess(bool enabled) {
  if (!enabled) return;
  std::vector<wchar_t> module(32768);
  const DWORD length = GetModuleFileNameW(nullptr, module.data(),
      static_cast<DWORD>(module.size()));
  if (length == 0 || length >= module.size()) return;
  Initialize(true, std::filesystem::path(std::wstring(module.data(), length))
                       .parent_path() / "user_data");
}

bool DpiDiagnostics::ReportDart(const Value& value) {
  const auto map = std::get_if<Map>(&value);
  if (!map) return false;
  constexpr const char* keys[] = {"event", "seq", "dpr", "physicalWidth",
      "physicalHeight", "logicalWidth", "logicalHeight", "textScale",
      "fontSize", "buildMicros", "rasterMicros", "mediaWidth", "mediaHeight",
      "frameBuildStartMicros", "frameRasterFinishMicros"};
  for (const auto& entry : *map) {
    const auto key = std::get_if<std::string>(&entry.first);
    if (!key || std::none_of(std::begin(keys), std::end(keys),
        [&](const char* allowed) { return *key == allowed; })) return false;
  }
  const auto event_value = Find(*map, "event");
  const auto event = event_value ? std::get_if<std::string>(event_value) : nullptr;
  if (!event || (*event != "metrics" && *event != "postFrame" &&
      *event != "frameTiming" && *event != "pointerDown")) return false;
  int64_t sequence = 0;
  if (!Integer(Find(*map, "seq"), 9007199254740991LL, &sequence)) return false;
  struct Field { const char* key; double low; double high; };
  constexpr Field fields[] = {{"dpr", 0.25, 16},
      {"physicalWidth", 0, 131072}, {"physicalHeight", 0, 131072},
      {"logicalWidth", 0, 524288}, {"logicalHeight", 0, 524288},
      {"textScale", 0.25, 16}, {"fontSize", 0, 1024}};
  std::ostringstream text;
  text.imbue(std::locale::classic());
  text << std::setprecision(12) << "\"event\":\"" << *event
       << "\",\"dartSeq\":" << sequence;
  for (const auto& field : fields) {
    double number = 0;
    if (!Number(Find(*map, field.key), field.low, field.high, &number)) return false;
    text << ",\"" << field.key << "\":" << number;
  }
  for (const char* key : {"buildMicros", "rasterMicros"}) {
    if (const auto timing = Find(*map, key)) {
      int64_t micros = 0;
      if (!Integer(timing, 60000000, &micros)) return false;
      text << ",\"" << key << "\":" << micros;
    }
  }
  for (const char* key : {"mediaWidth", "mediaHeight"}) {
    if (const auto dimension = Find(*map, key)) {
      double number = 0;
      if (!Number(dimension, 0, 524288, &number)) return false;
      text << ",\"" << key << "\":" << number;
    }
  }
  for (const char* key : {"frameBuildStartMicros", "frameRasterFinishMicros"}) {
    if (const auto timing = Find(*map, key)) {
      int64_t micros = 0;
      if (!Integer(timing, 9007199254740991LL, &micros)) return false;
      text << ",\"" << key << "\":" << micros;
    }
  }
  Write(text.str());
  return true;
}

void DpiDiagnostics::RecordNative(DpiNativeEvent event, HWND parent, HWND child,
    UINT host_dpi, bool applying_bounds, unsigned depth, UINT message_dpi,
    const RECT* suggested) {
  if (!enabled_) return;
  const char* name = NativeName(event);
  if (!name) return;
  ObserveTransition(event);
  std::ostringstream text;
  text.imbue(std::locale::classic());
  text << "\"event\":\"" << name << "\",\"hostDpi\":" << host_dpi
       << ",\"parentDpi\":" << (parent ? GetDpiForWindow(parent) : 0)
       << ",\"childDpi\":" << (child ? GetDpiForWindow(child) : 0)
       << ",\"messageDpi\":" << message_dpi
       << ",\"applyingBounds\":" << (applying_bounds ? 1 : 0)
       << ",\"depth\":" << depth;
  RECT parent_rect{}, child_rect{};
  if (parent && GetWindowRect(parent, &parent_rect)) Rectangle(text, "parent", parent_rect);
  if (child && GetClientRect(child, &child_rect)) Rectangle(text, "child", child_rect);
  if (suggested) Rectangle(text, "suggested", *suggested);
  AppendChildRenderCounts(text);
  Write(text.str());
}

bool DpiDiagnostics::ObservingChildRender() const {
  return enabled_ && render_deadline_millis_ != 0 &&
      GetTickCount64() < render_deadline_millis_;
}

void DpiDiagnostics::ObserveTransition(DpiNativeEvent event) {
  const bool new_transition = event == DpiNativeEvent::kEnterMove ||
      event == DpiNativeEvent::kParentDpi;
  const bool boundary = event == DpiNativeEvent::kChildBeforeParent ||
      event == DpiNativeEvent::kExitMove;
  if (new_transition || (boundary && !ObservingChildRender())) {
    ++render_transition_;
    render_deadline_millis_ = GetTickCount64() + 2000;
    resize_samples_remaining_ = 16;
    child_paint_count_ = 0;
    child_erase_count_ = 0;
  } else if (event == DpiNativeEvent::kExitMove) {
    // Include naturally arriving paints after the native drag loop returns,
    // keeping its existing counts and detail budget.
    render_deadline_millis_ = GetTickCount64() + 2000;
  }
}

void DpiDiagnostics::AppendChildRenderCounts(std::ostream& stream) const {
  if (render_transition_ == 0) return;
  stream << ",\"renderTransition\":" << render_transition_
         << ",\"paintCount\":" << child_paint_count_
         << ",\"eraseCount\":" << child_erase_count_;
}

void DpiDiagnostics::CountChildPaint(UINT message) {
  if (!enabled_ || (message != WM_PAINT && message != WM_ERASEBKGND) ||
      !ObservingChildRender()) return;
  unsigned& count = message == WM_PAINT ? child_paint_count_ : child_erase_count_;
  if (count < 1000000) ++count;
}

DpiDiagnostics::ChildResizeSample DpiDiagnostics::BeginChildResize(HWND child) {
  ChildResizeSample sample;
  if (!enabled_ || resize_samples_remaining_ == 0 ||
      !ObservingChildRender()) return sample;
  RECT before{};
  if (!GetClientRect(child, &before)) return sample;
  --resize_samples_remaining_;
  sample.before_width = before.right - before.left;
  sample.before_height = before.bottom - before.top;
  sample.started_transition = render_transition_;
  sample.started_micros = TimestampMicros();
  return sample;
}

void DpiDiagnostics::EndChildResize(const ChildResizeSample& sample, HWND child,
    LONG requested_width, LONG requested_height, bool success) {
  if (!enabled_ || sample.started_micros == 0) return;
  const auto ended_micros = TimestampMicros();
  RECT after{};
  const bool measured = GetClientRect(child, &after) != FALSE;
  std::ostringstream text;
  text.imbue(std::locale::classic());
  text << "\"event\":\"childResize\",\"startedMicros\":" << sample.started_micros
       << ",\"startedTransition\":" << sample.started_transition
       << ",\"durationMicros\":" << (ended_micros >= sample.started_micros ?
            ended_micros - sample.started_micros : 0)
       << ",\"beforeWidth\":" << sample.before_width
       << ",\"beforeHeight\":" << sample.before_height
       << ",\"requestedWidth\":" << requested_width
       << ",\"requestedHeight\":" << requested_height
       << ",\"afterWidth\":" << after.right - after.left
       << ",\"afterHeight\":" << after.bottom - after.top
       << ",\"resizeSucceeded\":" << (success ? 1 : 0)
       << ",\"afterMeasured\":" << (measured ? 1 : 0);
  AppendChildRenderCounts(text);
  Write(text.str());
}

void DpiDiagnostics::Write(const std::string& fields) {
  if (!enabled_) return;
  std::lock_guard<std::mutex> lock(mutex_);
  try {
    std::ostringstream line;
    line.imbue(std::locale::classic());
    line << "{\"seq\":" << ++sequence_ << ",\"micros\":" << TimestampMicros()
         << ",\"thread\":" << GetCurrentThreadId() << ',' << fields << "}\n";
    const auto value = line.str();
    if (value.size() > kMaximumBytes) return;
    std::error_code error;
    const auto size = std::filesystem::file_size(file_, error);
    if (!error && size + value.size() > kMaximumBytes) {
      const auto previous = std::filesystem::path(file_.wstring() + L".1");
      std::filesystem::remove(previous, error);
      error.clear();
      std::filesystem::rename(file_, previous, error);
      if (error) return;
    }
    std::ofstream stream(file_, std::ios::binary | std::ios::app);
    stream.write(value.data(), static_cast<std::streamsize>(value.size()));
  } catch (...) {
    // Diagnostic storage failures never alter window behavior.
  }
}
