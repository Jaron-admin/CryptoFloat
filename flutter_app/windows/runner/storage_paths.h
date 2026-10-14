#ifndef RUNNER_STORAGE_PATHS_H_
#define RUNNER_STORAGE_PATHS_H_

#include <windows.h>
#include <algorithm>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <regex>
#include <sstream>
#include <string>

// Keep the selector protocol aligned with data/storage_location.dart. The
// helper and main executable use their shared folder as the installation key.
namespace storage_paths {
enum class Mode { missing, invalid, portable, system };

inline Mode ReadMode(const std::filesystem::path& path) {
  std::error_code error;
  if (!std::filesystem::exists(path, error)) return error ? Mode::invalid : Mode::missing;
  std::ifstream input(path, std::ios::binary);
  if (!input) return Mode::invalid;
  std::string raw(4097, '\0');
  input.read(raw.data(), static_cast<std::streamsize>(raw.size()));
  raw.resize(static_cast<size_t>(input.gcount()));
  if (raw.size() > 4096) return Mode::invalid;
  static const std::regex pattern(R"mode(\s*\{\s*"mode"\s*:\s*"(portable|system)"\s*\}\s*)mode");
  std::smatch match;
  if (!std::regex_match(raw, match, pattern)) return Mode::invalid;
  return match[1] == "system" ? Mode::system : Mode::portable;
}

inline std::filesystem::path Selector(const std::filesystem::path& app,
                                      const std::filesystem::path& system) {
  auto identity = app.lexically_normal().wstring();
  std::replace(identity.begin(), identity.end(), L'/', L'\\');
  CharLowerBuffW(identity.data(), static_cast<DWORD>(identity.size()));
  const int count = WideCharToMultiByte(CP_UTF8, 0, identity.data(),
      static_cast<int>(identity.size()), nullptr, 0, nullptr, nullptr);
  std::string encoded(static_cast<size_t>(count), '\0');
  WideCharToMultiByte(CP_UTF8, 0, identity.data(), static_cast<int>(identity.size()),
      encoded.data(), count, nullptr, nullptr);
  uint32_t hash = 0x811c9dc5;
  for (const unsigned char byte : encoded) hash = (hash ^ byte) * 0x01000193;
  std::ostringstream name;
  name << std::hex << std::setfill('0') << std::setw(8) << hash << ".json";
  return system / ".storage-selection" / name.str();
}

inline std::filesystem::path Resolve(const std::filesystem::path& app,
                                     const std::filesystem::path& roaming) {
  const auto portable = app / "user_data";
  const auto system = roaming / "DuoMonitor";
  const auto legacy = roaming / "MetricPerch";
  Mode mode = ReadMode(Selector(app, system));
  if (mode == Mode::missing) mode = ReadMode(app / "duomonitor_storage.json");
  if (mode == Mode::invalid) return {};  // Never send secrets to a guessed store.
  const bool selected_legacy = mode == Mode::missing;
  if (mode == Mode::missing) {
    mode = ReadMode(app / "metricperch_storage.json");
    if (mode == Mode::missing || mode == Mode::invalid) {
      std::error_code error;
      if (std::filesystem::exists(portable / "settings.json", error)) return portable;
      mode = ReadMode(legacy / "storage_mode.json");
    }
  }
  if (mode != Mode::system) return portable;
  // Native startup can precede Dart's one-time copy of a legacy system store.
  std::error_code error;
  if (selected_legacy && !std::filesystem::exists(system / "settings.json", error) &&
      std::filesystem::exists(legacy / "settings.json", error)) return legacy;
  return system;
}

inline std::filesystem::path Environment(const wchar_t* name) {
  wchar_t value[32768]{};
  const DWORD length = GetEnvironmentVariableW(name, value, 32768);
  return length > 0 && length < 32768 ? std::filesystem::path(value) : std::filesystem::path();
}

inline std::filesystem::path ForProcess() {
  wchar_t module[32768]{};
  const DWORD length = GetModuleFileNameW(nullptr, module, 32768);
  if (length == 0 || length >= 32768) return {};
  auto roaming = Environment(L"APPDATA");
  if (roaming.empty()) {
    auto profile = Environment(L"USERPROFILE");
    if (profile.empty()) profile = L"C:\\Users\\Default";
    roaming = profile / "AppData" / "Roaming";
  }
  return Resolve(std::filesystem::path(module).parent_path(), roaming);
}
}  // namespace storage_paths
#endif  // RUNNER_STORAGE_PATHS_H_
