#include "platform_channel.h"

#include "notification_tray.h"
#include "system_proxy.h"
#include "context_menu.h"

#include <flutter/standard_method_codec.h>
#include <shlobj.h>
#include <wincrypt.h>
#include <dpapi.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <set>
#include <string>
#include <utility>
#include <vector>

namespace {

using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
using Result = flutter::MethodResult<Value>;

const Map* AsMap(const Value* value) {
  return value ? std::get_if<Map>(value) : nullptr;
}

const Value* Entry(const Map* map, const char* name) {
  if (!map) return nullptr;
  const auto item = map->find(Value(name));
  return item == map->end() ? nullptr : &item->second;
}

const std::string* Text(const Value* value) {
  return value ? std::get_if<std::string>(value) : nullptr;
}

bool Number(const Value* value, double* output) {
  if (!value) return false;
  if (const auto real = std::get_if<double>(value)) {
    *output = *real;
  } else if (const auto integer = std::get_if<int32_t>(value)) {
    *output = static_cast<double>(*integer);
  } else if (const auto long_integer = std::get_if<int64_t>(value)) {
    *output = static_cast<double>(*long_integer);
  } else {
    return false;
  }
  return std::isfinite(*output);
}

std::wstring WideText(const std::string& text) {
  if (text.empty()) return {};
  const int size = MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()),
      nullptr, 0);
  if (size <= 0) return {};
  std::wstring result(static_cast<size_t>(size), L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(),
                      static_cast<int>(text.size()), result.data(), size);
  return result;
}

std::string Utf8Text(const std::wstring& text) {
  if (text.empty()) return {};
  const int size = WideCharToMultiByte(
      CP_UTF8, 0, text.data(), static_cast<int>(text.size()), nullptr, 0,
      nullptr, nullptr);
  if (size <= 0) return {};
  std::string result(static_cast<size_t>(size), '\0');
  WideCharToMultiByte(CP_UTF8, 0, text.data(), static_cast<int>(text.size()),
                      result.data(), size, nullptr, nullptr);
  return result;
}

bool DecodeMenuStyle(const Map* values, ContextMenuStyle* style) {
  const auto colors = AsMap(Entry(values, "colors"));
  if (!colors) return false;
  const std::pair<const char*, COLORREF*> entries[] = {
      {"background", &style->background}, {"foreground", &style->foreground},
      {"secondary", &style->secondary}, {"border", &style->border},
      {"hover", &style->hover}, {"accent", &style->accent}};
  for (const auto& entry : entries) {
    const auto value = Entry(colors, entry.first);
    if (!value) return false;
    int64_t number = 0;
    if (const auto large = std::get_if<int64_t>(value)) {
      number = *large;
    } else if (const auto integer = std::get_if<int32_t>(value)) {
      number = *integer;
    } else {
      return false;
    }
    if (number < 0 || number > 0xffffffffLL) return false;
    const auto argb = static_cast<uint32_t>(number);
    // Native menus are always opaque, independently of the panel's alpha.
    *entry.second = RGB((argb >> 16) & 0xff, (argb >> 8) & 0xff, argb & 0xff);
  }
  if (const auto family = Text(Entry(values, "fontFamily"))) {
    style->font_family = WideText(*family);
    if (style->font_family.size() >= LF_FACESIZE) return false;
  }
  // Labels arrive with the palette so tray and panel menus share one locale.
  // Older callers without labels retain the neutral English defaults.
  if (const auto label_value = Entry(values, "labels")) {
    const auto labels = AsMap(label_value);
    if (!labels) return false;
    const std::pair<const char*, std::wstring*> names[] = {
        {"hide", &style->hide_label}, {"show", &style->show_label},
        {"refresh", &style->refresh_label}, {"topmost", &style->topmost_label},
        {"settings", &style->settings_label}, {"exit", &style->exit_label}};
    for (const auto& name : names) {
      const auto label = Text(Entry(labels, name.first));
      if (!label || label->empty() || label->size() > 320) return false;
      auto wide = WideText(*label);
      if (wide.empty() || wide.size() > 80 ||
          wide.find(L'\0') != std::wstring::npos ||
          wide.find_first_of(L"\r\n\t") != std::wstring::npos) {
        return false;
      }
      *name.second = std::move(wide);
    }
  }
  return true;
}

bool DecodeBounds(const Map* values, Win32Window::Bounds* bounds) {
  double x = 0, y = 0, width = 0, height = 0;
  if (!Number(Entry(values, "x"), &x) ||
      !Number(Entry(values, "y"), &y) ||
      !Number(Entry(values, "width"), &width) ||
      !Number(Entry(values, "height"), &height) ||
      std::abs(x) > 100000 || std::abs(y) > 100000 ||
      width <= 0 || width > 100000 || height <= 0 || height > 100000) {
    return false;
  }
  const LONG left = static_cast<LONG>(std::lround(x));
  const LONG top = static_cast<LONG>(std::lround(y));
  bounds->rect = RECT{left, top, left + static_cast<LONG>(std::lround(width)),
                      top + static_cast<LONG>(std::lround(height))};
  if (const auto display = Text(Entry(values, "displayId"))) {
    bounds->display_id = WideText(*display);
  }
  double scale = 1.0;
  if (Number(Entry(values, "scale"), &scale)) {
    bounds->scale = std::clamp(scale, 0.5, 8.0);
  }
  return true;
}

Value EncodeBounds(const Win32Window::Bounds& bounds) {
  return Value(Map{
      {Value("x"), Value(static_cast<double>(bounds.rect.left))},
      {Value("y"), Value(static_cast<double>(bounds.rect.top))},
      {Value("width"),
       Value(static_cast<double>(bounds.rect.right - bounds.rect.left))},
      {Value("height"),
       Value(static_cast<double>(bounds.rect.bottom - bounds.rect.top))},
      {Value("displayId"), Value(Utf8Text(bounds.display_id))},
      {Value("scale"), Value(bounds.scale)},
  });
}

int CALLBACK FontFamily(const LOGFONTW* font, const TEXTMETRICW*, DWORD,
                        LPARAM parameter) {
  auto families = reinterpret_cast<std::set<std::wstring>*>(parameter);
  // Vertical variants share their family with the corresponding horizontal face.
  if (font->lfFaceName[0] != L'@' && font->lfFaceName[0] != L'\0') {
    families->insert(font->lfFaceName);
  }
  return 1;
}

Value SystemFonts() {
  std::set<std::wstring> families;
  HDC context = GetDC(nullptr);
  if (context) {
    LOGFONTW font{};
    font.lfCharSet = DEFAULT_CHARSET;
    EnumFontFamiliesExW(context, &font, FontFamily,
                        reinterpret_cast<LPARAM>(&families), 0);
    ReleaseDC(nullptr, context);
  }
  flutter::EncodableList result;
  result.reserve(families.size());
  for (const auto& family : families) result.emplace_back(Utf8Text(family));
  return Value(std::move(result));
}

int CALLBACK InstalledFontName(const LOGFONTW* font, const TEXTMETRICW*, DWORD,
                               LPARAM parameter) {
  auto canonical = reinterpret_cast<std::wstring*>(parameter);
  if (font->lfFaceName[0] == L'@') return 1;
  *canonical = font->lfFaceName;
  return 0;
}

uint32_t FontWord(const uint8_t* bytes) {
  return (static_cast<uint32_t>(bytes[0]) << 24) |
         (static_cast<uint32_t>(bytes[1]) << 16) |
         (static_cast<uint32_t>(bytes[2]) << 8) | bytes[3];
}

void SetFontWord(uint8_t* bytes, uint32_t value) {
  bytes[0] = static_cast<uint8_t>(value >> 24);
  bytes[1] = static_cast<uint8_t>(value >> 16);
  bytes[2] = static_cast<uint8_t>(value >> 8);
  bytes[3] = static_cast<uint8_t>(value);
}

uint32_t FontChecksum(const uint8_t* bytes, size_t length) {
  uint32_t sum = 0;
  for (size_t offset = 0; offset < length; offset += 4) {
    sum += FontWord(bytes + offset);
  }
  return sum;
}

bool ReadSelectedFont(HDC context, std::vector<uint8_t>* bytes) {
  constexpr size_t limit = 64 * 1024 * 1024;
  constexpr DWORD collection_tag = 0x66637474;  // GDI's little-endian 'ttcf'.
  if (GetFontData(context, collection_tag, 0, nullptr, 0) == GDI_ERROR) {
    const DWORD size = GetFontData(context, 0, 0, nullptr, 0);
    if (size == GDI_ERROR || size == 0 || size > limit) return false;
    bytes->resize(size);
    return GetFontData(context, 0, 0, bytes->data(), size) == size;
  }

  // For TTCs, GDI table offsets still refer to the containing collection.
  // Extract this face's tables into a standalone sfnt, preserving the exact face
  // rather than loading the collection's first face under the selected alias.
  uint8_t header[12]{};
  if (GetFontData(context, 0, 0, header, 12) != 12) return false;
  const uint32_t signature = FontWord(header);
  if (signature != 0x00010000 && signature != 0x4f54544f) return false;
  const size_t count = (static_cast<size_t>(header[4]) << 8) | header[5];
  if (count == 0 || count > 4096) return false;
  const size_t directory_size = 12 + count * 16;
  bytes->resize(directory_size);
  if (GetFontData(context, 0, 0, bytes->data(),
                   static_cast<DWORD>(directory_size)) != directory_size) {
    return false;
  }
  size_t head_offset = 0;
  for (size_t index = 0; index < count; ++index) {
    const size_t record_offset = 12 + index * 16;
    const uint8_t* record = bytes->data() + record_offset;
    const DWORD tag = static_cast<DWORD>(record[0]) |
                      (static_cast<DWORD>(record[1]) << 8) |
                      (static_cast<DWORD>(record[2]) << 16) |
                      (static_cast<DWORD>(record[3]) << 24);
    const uint32_t big_tag = FontWord(record);
    const DWORD length = FontWord(record + 12);
    const size_t padded = (static_cast<size_t>(length) + 3) & ~size_t{3};
    const size_t destination = bytes->size();
    if (padded > limit || destination > limit - padded) return false;
    bytes->resize(destination + padded, 0);
    if (length > 0 && GetFontData(context, tag, 0,
                                  bytes->data() + destination, length) != length) {
      return false;
    }
    if (big_tag == 0x68656164) {  // 'head'
      if (length < 12) return false;
      head_offset = destination;
      SetFontWord(bytes->data() + destination + 8, 0);
    }
    SetFontWord(bytes->data() + record_offset + 4,
                 FontChecksum(bytes->data() + destination, padded));
    SetFontWord(bytes->data() + record_offset + 8,
                 static_cast<uint32_t>(destination));
  }
  if (head_offset == 0) return false;
  SetFontWord(bytes->data() + head_offset + 8,
               0xb1b0afba - FontChecksum(bytes->data(), bytes->size()));
  return true;
}

void InstalledFontData(const std::string& requested, Result* result) {
  const std::wstring name = WideText(requested);
  // Names come from the existing GDI enumeration, whose face field is bounded.
  if (name.empty() || name.size() >= LF_FACESIZE) {
    result->Error("font_unavailable", "The installed font name is not supported.");
    return;
  }
  LOGFONTW logical{};
  logical.lfCharSet = DEFAULT_CHARSET;
  std::copy(name.begin(), name.end(), logical.lfFaceName);
  HDC context = CreateCompatibleDC(nullptr);
  std::wstring canonical;
  if (context) {
    EnumFontFamiliesExW(context, &logical, InstalledFontName,
                        reinterpret_cast<LPARAM>(&canonical), 0);
  }
  if (canonical.empty()) {
    if (context) DeleteDC(context);
    result->Error("font_unavailable", "The selected font face is no longer installed.");
    return;
  }
  // A valid English family alias can enumerate a localized GDI face name.
  // Resolve that installed name before selecting the font; enumeration of a
  // missing name returns no face, whereas CreateFont would choose a fallback.
  std::fill(std::begin(logical.lfFaceName), std::end(logical.lfFaceName), L'\0');
  std::copy(canonical.begin(), canonical.end(), logical.lfFaceName);
  logical.lfHeight = -16;
  logical.lfWeight = FW_NORMAL;
  HFONT font = CreateFontIndirectW(&logical);
  if (!context || !font) {
    if (context) DeleteDC(context);
    if (font) DeleteObject(font);
    result->Error("font_unavailable", "Windows could not open the installed font.");
    return;
  }
  const HGDIOBJ previous = SelectObject(context, font);
  wchar_t selected[LF_FACESIZE]{};
  const bool exact = GetTextFaceW(context, LF_FACESIZE, selected) > 0 &&
                     CompareStringOrdinal(canonical.c_str(), -1, selected, -1,
                                           TRUE) == CSTR_EQUAL;
  // GDI silently chooses a fallback for unknown names. Never register that
  // fallback under the selected face's alias and pretend the font loaded.
  std::vector<uint8_t> bytes;
  const bool loaded = exact && ReadSelectedFont(context, &bytes);
  SelectObject(context, previous);
  DeleteObject(font);
  DeleteDC(context);
  if (loaded) {
    result->Success(Value(std::move(bytes)));
  } else {
    result->Error("font_unavailable", "Windows could not read the selected font face.");
  }
}

class FileHandle {
 public:
  explicit FileHandle(HANDLE handle) : handle_(handle) {}
  ~FileHandle() { Close(); }
  bool valid() const { return handle_ != INVALID_HANDLE_VALUE; }
  HANDLE get() const { return handle_; }
  void Close() {
    if (valid()) {
      CloseHandle(handle_);
      handle_ = INVALID_HANDLE_VALUE;
    }
  }

 private:
  HANDLE handle_;
};

// Both CryptProtectData and CryptUnprotectData allocate with LocalAlloc.
class ProtectedBlob {
 public:
  ~ProtectedBlob() {
    if (value.pbData) {
      SecureZeroMemory(value.pbData, value.cbData);
      LocalFree(value.pbData);
    }
  }
  DATA_BLOB value{};
};

bool CredentialFile(const std::string& key, std::wstring* path) {
  // Hash references so user-controlled identifiers never become file paths.
  HCRYPTPROV provider = 0;
  HCRYPTHASH hash = 0;
  BYTE digest[32]{};
  DWORD digest_size = static_cast<DWORD>(sizeof(digest));
  bool success = CryptAcquireContextW(&provider, nullptr, nullptr, PROV_RSA_AES,
                                      CRYPT_VERIFYCONTEXT) != FALSE;
  if (success) {
    success = CryptCreateHash(provider, CALG_SHA_256, 0, 0, &hash) != FALSE;
  }
  if (success) {
    success = CryptHashData(hash, reinterpret_cast<const BYTE*>(key.data()),
                            static_cast<DWORD>(key.size()), 0) != FALSE &&
              CryptGetHashParam(hash, HP_HASHVAL, digest, &digest_size, 0) != FALSE;
  }
  if (hash) CryptDestroyHash(hash);
  if (provider) CryptReleaseContext(provider, 0);
  if (!success) return false;

  std::vector<wchar_t> module(32768);
  const DWORD length = GetModuleFileNameW(nullptr, module.data(),
                                         static_cast<DWORD>(module.size()));
  if (length == 0 || length >= module.size()) return false;
  const std::wstring executable(module.data(), length);
  const auto separator = executable.find_last_of(L"\\/");
  if (separator == std::wstring::npos) return false;
  std::wstring directory = executable.substr(0, separator) + L"\\user_data";
  if (!CreateDirectoryW(directory.c_str(), nullptr) &&
      GetLastError() != ERROR_ALREADY_EXISTS) return false;
  directory += L"\\secrets";
  if (!CreateDirectoryW(directory.c_str(), nullptr) &&
      GetLastError() != ERROR_ALREADY_EXISTS) return false;

  constexpr wchar_t hex[] = L"0123456789abcdef";
  std::wstring filename;
  filename.reserve(64);
  for (const BYTE byte : digest) {
    filename.push_back(hex[byte >> 4]);
    filename.push_back(hex[byte & 0x0f]);
  }
  *path = directory + L"\\" + filename + L".dpapi";
  return true;
}

bool WriteCredential(const std::wstring& path, const std::string& value) {
  std::vector<BYTE> plaintext(value.begin(), value.end());
  if (plaintext.empty()) plaintext.push_back(0);
  DATA_BLOB input{static_cast<DWORD>(value.size()), plaintext.data()};
  ProtectedBlob encrypted;
  // Omitting CRYPTPROTECT_LOCAL_MACHINE binds the blob to the current user.
  const BOOL protected_ok = CryptProtectData(
      &input, L"CryptoFloat credential", nullptr, nullptr, nullptr,
      CRYPTPROTECT_UI_FORBIDDEN, &encrypted.value);
  if (!plaintext.empty()) SecureZeroMemory(plaintext.data(), plaintext.size());
  if (!protected_ok) return false;

  const std::wstring temporary = path + L".tmp";
  FileHandle file(CreateFileW(temporary.c_str(), GENERIC_WRITE, 0, nullptr,
                              CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL |
                                  FILE_FLAG_WRITE_THROUGH,
                              nullptr));
  if (!file.valid()) return false;
  DWORD written = 0;
  bool success = WriteFile(file.get(), encrypted.value.pbData,
                           encrypted.value.cbData, &written, nullptr) != FALSE &&
                 written == encrypted.value.cbData &&
                 FlushFileBuffers(file.get()) != FALSE;
  file.Close();
  if (success) {
    success = MoveFileExW(temporary.c_str(), path.c_str(),
                          MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) != FALSE;
  }
  if (!success) DeleteFileW(temporary.c_str());
  return success;
}

void ReadCredential(const std::wstring& path, Result* result) {
  FileHandle file(CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ,
                              nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL,
                              nullptr));
  if (!file.valid()) {
    const DWORD error = GetLastError();
    if (error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND) {
      result->Success(Value());
    } else {
      result->Error("secret_store_failure", "Windows could not read the credential.");
    }
    return;
  }
  LARGE_INTEGER size{};
  if (!GetFileSizeEx(file.get(), &size) || size.QuadPart <= 0 ||
      size.QuadPart > 1024 * 1024) {
    result->Error("secret_store_failure", "The protected credential is invalid.");
    return;
  }
  std::vector<BYTE> ciphertext(static_cast<size_t>(size.QuadPart));
  DWORD read = 0;
  if (!ReadFile(file.get(), ciphertext.data(), static_cast<DWORD>(ciphertext.size()),
                 &read, nullptr) || read != ciphertext.size()) {
    result->Error("secret_store_failure", "Windows could not read the credential.");
    return;
  }
  DATA_BLOB input{static_cast<DWORD>(ciphertext.size()), ciphertext.data()};
  ProtectedBlob plaintext;
  if (!CryptUnprotectData(&input, nullptr, nullptr, nullptr, nullptr,
                          CRYPTPROTECT_UI_FORBIDDEN, &plaintext.value)) {
    result->Error("secret_store_failure",
                  "Windows could not unlock the credential for this user.");
    return;
  }
  std::string value;
  if (plaintext.value.cbData > 0) {
    value.assign(reinterpret_cast<const char*>(plaintext.value.pbData),
                  plaintext.value.cbData);
  }
  result->Success(Value(value));
  if (!value.empty()) SecureZeroMemory(value.data(), value.size());
}

void InvalidArguments(Result* result) {
  result->Error("invalid_arguments", "The platform request has invalid arguments.");
}

void WindowResult(bool success, Result* result) {
  if (success) {
    result->Success();
  } else {
    result->Error("window_operation_failed", "Windows could not update the panel.");
  }
}

}  // namespace

PlatformChannel::PlatformChannel(Win32Window* window,
                                 flutter::BinaryMessenger* messenger)
    : window_(window),
      channel_(std::make_unique<flutter::MethodChannel<Value>>(
          messenger, "cryptofloat/platform",
          &flutter::StandardMethodCodec::GetInstance())) {
  context_menu_ = std::make_shared<ContextMenu>(window_->GetHandle());
  tray_ = std::make_unique<NotificationTray>(
      window_->GetHandle(), [this](const std::string& action) {
        channel_->InvokeMethod("tray.action", std::make_unique<Value>(action));
      }, [this](POINT point) {
        context_menu_->ShowTray(point, [this](const std::string& action) {
          if (action == "show" || action == "settings") {
            window_->ClampToVisibleWorkArea();
            tray_->ShowWindow();
          }
          channel_->InvokeMethod("tray.action", std::make_unique<Value>(action));
        });
      });
  system_proxy_ = std::make_unique<SystemProxy>(window_->GetHandle());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<Value>& call,
             std::unique_ptr<Result> result) {
        HandleMethod(call, std::move(result));
      });
}

PlatformChannel::~PlatformChannel() {
  context_menu_->Shutdown();
  channel_->SetMethodCallHandler(nullptr);
  // Cancel asynchronous requests before the messenger goes away. The worker
  // callbacks retain only detached job state, never this channel or its result.
  system_proxy_.reset();
  tray_.reset();
  context_menu_.reset();
}

bool PlatformChannel::HandleWindowMessage(UINT message, WPARAM wparam,
                                           LPARAM lparam, LRESULT* result) {
  // A menu owns a nested Windows message loop; retain its object if shutdown
  // destroys this platform channel while the popup is open.
  const auto menu = context_menu_;
  if (menu && menu->HandleMessage(message, wparam, lparam, result)) return true;
  *result = 0;
  if (system_proxy_ && system_proxy_->HandleMessage(message, wparam, lparam)) {
    return true;
  }
  return tray_ && tray_->HandleMessage(message, wparam, lparam);
}

void PlatformChannel::HandleMethod(const flutter::MethodCall<Value>& call,
                                   std::unique_ptr<Result> result) {
  const std::string& method = call.method_name();
  const Value* arguments = call.arguments();
  const Map* values = AsMap(arguments);

  if (method == "window.initialize") {
    const auto topmost_value = Entry(values, "alwaysOnTop");
    const auto topmost = topmost_value ? std::get_if<bool>(topmost_value) : nullptr;
    double opacity = 0.96;
    if (!topmost || !Number(Entry(values, "opacity"), &opacity)) {
      InvalidArguments(result.get());
      return;
    }
    if (const auto saved = Entry(values, "bounds")) {
      Win32Window::Bounds bounds;
      if (!DecodeBounds(AsMap(saved), &bounds)) {
        InvalidArguments(result.get());
        return;
      }
      window_->ApplyWindowBounds(bounds);
    } else {
      window_->ClampToVisibleWorkArea();
    }
    const bool updated = window_->SetAlwaysOnTop(*topmost);
    // An unavailable notification area must never prevent normal startup.
    tray_->EnsureIcon();
    WindowResult(window_->SetOpacity(opacity) && updated, result.get());
  } else if (method == "window.hideToTray") {
    result->Success(Value(tray_->HideWindow()));
  } else if (method == "window.showFromTray") {
    window_->ClampToVisibleWorkArea();
    result->Success(Value(tray_->ShowWindow()));
  } else if (method == "window.setMenuAppearance") {
    ContextMenuStyle style;
    if (!DecodeMenuStyle(values, &style)) {
      InvalidArguments(result.get());
      return;
    }
    context_menu_->SetAppearance(style);
    result->Success();
  } else if (method == "window.showContextMenu") {
    ContextMenuStyle style;
    double x = 0, y = 0;
    const auto topmost_value = Entry(values, "alwaysOnTop");
    const auto topmost = topmost_value ? std::get_if<bool>(topmost_value) : nullptr;
    if (!topmost || !DecodeMenuStyle(values, &style) ||
        !Number(Entry(values, "x"), &x) || !Number(Entry(values, "y"), &y) ||
        std::abs(x) > 100000 || std::abs(y) > 100000) {
      InvalidArguments(result.get());
      return;
    }
    const HWND hwnd = window_->GetHandle();
    const UINT dpi = GetDpiForWindow(hwnd);
    const double scale = (dpi == 0 ? 96 : dpi) / 96.0;
    POINT point{static_cast<LONG>(std::lround(x * scale)),
                static_cast<LONG>(std::lround(y * scale))};
    if (!ClientToScreen(hwnd, &point)) {
      WindowResult(false, result.get());
      return;
    }
    context_menu_->ShowPanel(point, *topmost, style, std::move(result));
  } else if (method == "network.resolveSystemProxy") {
    const auto url = Text(Entry(values, "url"));
    if (url) {
      system_proxy_->Resolve(*url, std::move(result));
    } else {
      InvalidArguments(result.get());
    }
  } else if (method == "window.setAlwaysOnTop") {
    const auto enabled = arguments ? std::get_if<bool>(arguments) : nullptr;
    if (enabled) {
      WindowResult(window_->SetAlwaysOnTop(*enabled), result.get());
    } else {
      InvalidArguments(result.get());
    }
  } else if (method == "window.setOpacity") {
    double opacity = 0;
    if (Number(arguments, &opacity)) {
      WindowResult(window_->SetOpacity(opacity), result.get());
    } else {
      InvalidArguments(result.get());
    }
  } else if (method == "window.getBounds") {
    result->Success(EncodeBounds(window_->GetWindowBounds()));
  } else if (method == "window.setBounds") {
    Win32Window::Bounds bounds;
    if (DecodeBounds(values, &bounds)) {
      window_->ApplyWindowBounds(bounds);
      result->Success();
    } else {
      InvalidArguments(result.get());
    }
  } else if (method == "window.beginDrag") {
    WindowResult(window_->BeginMoveOrResize(HTCAPTION), result.get());
  } else if (method == "window.beginResize") {
    const auto edge = Text(arguments);
    const std::pair<const char*, int> edges[] = {
        {"left", HTLEFT}, {"right", HTRIGHT}, {"top", HTTOP}, {"bottom", HTBOTTOM},
        {"topLeft", HTTOPLEFT}, {"topRight", HTTOPRIGHT},
        {"bottomLeft", HTBOTTOMLEFT}, {"bottomRight", HTBOTTOMRIGHT}};
    int hit = HTNOWHERE;
    if (edge) {
      for (const auto& candidate : edges) {
        if (*edge == candidate.first) hit = candidate.second;
      }
    }
    if (hit != HTNOWHERE) {
      WindowResult(window_->BeginMoveOrResize(hit), result.get());
    } else {
      InvalidArguments(result.get());
    }
  } else if (method == "window.setSettingsMode") {
    const auto enabled = arguments ? std::get_if<bool>(arguments) : nullptr;
    if (enabled) {
      window_->SetSettingsMode(*enabled);
      result->Success();
    } else {
      InvalidArguments(result.get());
    }
  } else if (method == "window.close") {
    // Reply before destroying the messenger that carries the reply.
    result->Success();
    PostMessage(window_->GetHandle(), WM_CLOSE, 0, 0);
  } else if (method == "window.getSystemFonts") {
    result->Success(SystemFonts());
  } else if (method == "window.getFontData") {
    const auto requested = Text(arguments);
    if (requested && !requested->empty() && requested->size() <= 128) {
      InstalledFontData(*requested, result.get());
    } else {
      InvalidArguments(result.get());
    }
  } else if (method == "secret.write" || method == "secret.read" ||
              method == "secret.delete") {
    const auto key = Text(Entry(values, "key"));
    if (!key || key->empty() || key->size() > 2048) {
      InvalidArguments(result.get());
      return;
    }
    std::wstring path;
    if (!CredentialFile(*key, &path)) {
      result->Error("secret_store_failure", "Windows protected storage is unavailable.");
      return;
    }
    if (method == "secret.write") {
      const auto value = Text(Entry(values, "value"));
      if (!value || value->size() > 65536) {
        InvalidArguments(result.get());
      } else if (WriteCredential(path, *value)) {
        result->Success();
      } else {
        result->Error("secret_store_failure", "Windows could not protect or save the credential.");
      }
    } else if (method == "secret.read") {
      ReadCredential(path, result.get());
    } else if (DeleteFileW(path.c_str()) || GetLastError() == ERROR_FILE_NOT_FOUND ||
               GetLastError() == ERROR_PATH_NOT_FOUND) {
      result->Success();
    } else {
      result->Error("secret_store_failure", "Windows could not delete the credential.");
    }
  } else {
    result->NotImplemented();
  }
}
