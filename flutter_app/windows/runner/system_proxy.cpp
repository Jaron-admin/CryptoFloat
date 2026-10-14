#include "system_proxy.h"

#include <winhttp.h>

#include <algorithm>
#include <atomic>
#include <cwctype>
#include <map>
#include <mutex>
#include <utility>
#include <vector>

namespace {
using Value = flutter::EncodableValue;
using Result = flutter::MethodResult<Value>;
constexpr UINT kProxyComplete = WM_APP + 0x34;
constexpr UINT_PTR kProxyTimer = 0xCFF1;
constexpr ULONGLONG kDeadlineMs = 6000;
std::atomic<UINT_PTR> next_job_id{1};

struct Resolution {
  std::string route;
  std::string error;
};

std::wstring Wide(const std::string& text) {
  if (text.empty() || text.size() > 16384) return {};
  const int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
      text.data(), static_cast<int>(text.size()), nullptr, 0);
  if (count <= 0) return {};
  std::wstring result(static_cast<size_t>(count), L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(),
      static_cast<int>(text.size()), result.data(), count);
  return result;
}

std::string Utf8(const std::wstring& text) {
  const int count = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS,
      text.data(), static_cast<int>(text.size()), nullptr, 0, nullptr, nullptr);
  if (count <= 0) return {};
  std::string result(static_cast<size_t>(count), '\0');
  WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, text.data(),
      static_cast<int>(text.size()), result.data(), count, nullptr, nullptr);
  return result;
}

std::wstring Lower(std::wstring text) {
  std::transform(text.begin(), text.end(), text.begin(),
                 [](wchar_t character) { return static_cast<wchar_t>(towlower(character)); });
  return text;
}

std::vector<std::wstring> Tokens(const std::wstring& text) {
  std::vector<std::wstring> result;
  size_t offset = 0;
  while (offset < text.size()) {
    offset = text.find_first_not_of(L"; \t\r\n", offset);
    if (offset == std::wstring::npos) break;
    const size_t end = text.find_first_of(L"; \t\r\n", offset);
    result.push_back(text.substr(offset, end - offset));
    if (end == std::wstring::npos) break;
    offset = end + 1;
  }
  return result;
}

bool Matches(const std::wstring& pattern, const std::wstring& host) {
  size_t pattern_at = 0, host_at = 0;
  size_t star = std::wstring::npos, retry = 0;
  while (host_at < host.size()) {
    if (pattern_at < pattern.size() &&
        (pattern[pattern_at] == L'?' || pattern[pattern_at] == host[host_at])) {
      ++pattern_at;
      ++host_at;
    } else if (pattern_at < pattern.size() && pattern[pattern_at] == L'*') {
      star = pattern_at++;
      retry = host_at;
    } else if (star != std::wstring::npos) {
      pattern_at = star + 1;
      host_at = ++retry;
    } else {
      return false;
    }
  }
  while (pattern_at < pattern.size() && pattern[pattern_at] == L'*') ++pattern_at;
  return pattern_at == pattern.size();
}

bool Bypasses(const std::wstring& bypass, const std::wstring& hostname,
              INTERNET_PORT port) {
  const std::wstring host = Lower(hostname);
  const std::wstring with_port = host + L":" + std::to_wstring(port);
  for (auto pattern : Tokens(Lower(bypass))) {
    if (pattern == L"<local>") {
      if (host.find_first_of(L".:") == std::wstring::npos) return true;
      continue;
    }
    if (pattern.compare(0, 8, L"https://") == 0) pattern.erase(0, 8);
    if (Matches(pattern, host) || Matches(pattern, with_port)) return true;
  }
  return false;
}

bool ValidHost(const std::wstring& host) {
  if (host.empty() || host.size() > 255) return false;
  return std::all_of(host.begin(), host.end(), [](wchar_t character) {
    return (character >= L'a' && character <= L'z') ||
           (character >= L'A' && character <= L'Z') ||
           (character >= L'0' && character <= L'9') ||
           character == L'.' || character == L'-' || character == L'_' ||
           character == L':' || character == L'%' || character == L'[' ||
           character == L']';
  });
}

Resolution Endpoint(std::wstring endpoint) {
  const std::wstring lower = Lower(endpoint);
  if (lower.compare(0, 7, L"http://") == 0) {
    endpoint.erase(0, 7);
  } else if (endpoint.find(L"://") != std::wstring::npos) {
    return {{}, "system_proxy_unsupported"};
  }
  if (endpoint.empty() || endpoint.find_first_of(L"/\\@?#=; \t\r\n") !=
                              std::wstring::npos) {
    return {{}, "system_proxy_invalid"};
  }
  std::wstring host, port = L"80";
  if (endpoint.front() == L'[') {
    const size_t close = endpoint.find(L']');
    if (close == std::wstring::npos) return {{}, "system_proxy_invalid"};
    host = endpoint.substr(0, close + 1);
    if (close + 1 < endpoint.size()) {
      if (endpoint[close + 1] != L':') return {{}, "system_proxy_invalid"};
      port = endpoint.substr(close + 2);
    }
  } else {
    const size_t colon = endpoint.find(L':');
    host = endpoint.substr(0, colon);
    if (colon != std::wstring::npos) port = endpoint.substr(colon + 1);
  }
  if (!ValidHost(host) || port.empty() || port.size() > 5 ||
      !std::all_of(port.begin(), port.end(),
                   [](wchar_t digit) { return digit >= L'0' && digit <= L'9'; })) {
    return {{}, "system_proxy_invalid"};
  }
  unsigned int number = 0;
  for (const auto digit : port) number = number * 10 + static_cast<unsigned int>(digit - L'0');
  if (number == 0 || number > 65535) return {{}, "system_proxy_invalid"};
  return {"PROXY " + Utf8(host) + ":" + std::to_string(number), {}};
}

Resolution StaticProxy(const std::wstring& proxy) {
  std::vector<std::wstring> selected;
  std::vector<std::wstring> fallback;
  bool socks = false;
  const auto tokens = Tokens(proxy);
  const bool mapped = proxy.find(L'=') != std::wstring::npos;
  for (const auto& token : tokens) {
    const size_t equal = token.find(L'=');
    if (!mapped || equal == std::wstring::npos) {
      fallback.push_back(token);
    } else {
      const std::wstring scheme = Lower(token.substr(0, equal));
      if (scheme == L"https") selected.push_back(token.substr(equal + 1));
      if (scheme == L"socks" || scheme == L"socks4" || scheme == L"socks5") socks = true;
    }
  }
  if (selected.empty()) selected = std::move(fallback);
  if (selected.empty()) {
    // A SOCKS fallback applies to HTTPS too, but Dart's transport cannot use it.
    return socks ? Resolution{{}, "system_proxy_unsupported"}
                 : Resolution{"DIRECT", {}};
  }
  Resolution result;
  for (const auto& endpoint : selected) {
    const Resolution route = Endpoint(endpoint);
    if (!route.error.empty()) return route;
    if (!result.route.empty()) result.route += "; ";
    result.route += route.route;
  }
  return result;
}

struct CurrentProxy {
  WINHTTP_CURRENT_USER_IE_PROXY_CONFIG value{};
  ~CurrentProxy() {
    if (value.lpszAutoConfigUrl) GlobalFree(value.lpszAutoConfigUrl);
    if (value.lpszProxy) GlobalFree(value.lpszProxy);
    if (value.lpszProxyBypass) GlobalFree(value.lpszProxyBypass);
  }
};

struct Job {
  std::mutex mutex;
  HWND window = nullptr;
  UINT_PTR id = 0;
  HINTERNET session = nullptr;
  HINTERNET resolver = nullptr;
  bool detect_stage = false;
  bool complete = false;
  std::wstring url;
  std::wstring automatic_url;
  WINHTTP_AUTOPROXY_OPTIONS options{};
  Resolution outcome;
};

Resolution AutomaticResult(HINTERNET resolver) {
  WINHTTP_PROXY_RESULT proxy{};
  if (WinHttpGetProxyResult(resolver, &proxy) != ERROR_SUCCESS) {
    return {{}, "system_proxy_autoconfig_failed"};
  }
  Resolution result;
  if (proxy.cEntries == 0 || proxy.cEntries > 32) {
    result.error = "system_proxy_autoconfig_failed";
  }
  for (DWORD index = 0; index < proxy.cEntries && result.error.empty(); ++index) {
    const auto& entry = proxy.pEntries[index];
    Resolution route;
    if (!entry.fProxy) {
      route.route = "DIRECT";
    } else if (entry.ProxyScheme != INTERNET_SCHEME_HTTP) {
      route.error = "system_proxy_unsupported";
    } else if (!entry.pwszProxy || entry.ProxyPort == 0) {
      route.error = "system_proxy_invalid";
    } else {
      std::wstring host(entry.pwszProxy);
      if (host.find(L':') != std::wstring::npos && host.front() != L'[') {
        host = L"[" + host + L"]";
      }
      route = Endpoint(host + L":" + std::to_wstring(entry.ProxyPort));
    }
    if (!route.error.empty()) {
      result.error = route.error;
    } else {
      if (!result.route.empty()) result.route += "; ";
      result.route += route.route;
    }
  }
  WinHttpFreeProxyResult(&proxy);
  return result;
}

void CALLBACK ProxyCallback(HINTERNET resolver, DWORD_PTR context,
                            DWORD status, void* information, DWORD size) {
  if (!context) return;
  auto retained = reinterpret_cast<std::shared_ptr<Job>*>(context);
  // HANDLE_CLOSING is the last callback for this resolver; this reference keeps
  // state alive even when the platform channel has already been destroyed.
  if (status == WINHTTP_CALLBACK_STATUS_HANDLE_CLOSING) {
    delete retained;
    return;
  }
  if (status != WINHTTP_CALLBACK_STATUS_GETPROXYFORURL_COMPLETE &&
      status != WINHTTP_CALLBACK_STATUS_REQUEST_ERROR) return;
  const auto job = *retained;
  std::lock_guard<std::mutex> lock(job->mutex);
  if (!job->window || job->complete) return;
  if (status == WINHTTP_CALLBACK_STATUS_GETPROXYFORURL_COMPLETE) {
    job->outcome = AutomaticResult(resolver);
  } else {
    const auto error = size >= sizeof(WINHTTP_ASYNC_RESULT) && information
        ? static_cast<const WINHTTP_ASYNC_RESULT*>(information)->dwError : 0;
    // Only an absent WPAD configuration advances to the next mechanism. An
    // actual PAC download/script failure is never silently treated as DIRECT.
    job->outcome = job->detect_stage && error == ERROR_WINHTTP_AUTODETECTION_FAILED
        ? Resolution{{}, "autodetect_not_found"}
        : Resolution{{}, "system_proxy_autoconfig_failed"};
  }
  job->complete = true;
  PostMessageW(job->window, kProxyComplete, job->id, 0);
}

void Stop(const std::shared_ptr<Job>& job) {
  HINTERNET resolver = nullptr, session = nullptr;
  {
    std::lock_guard<std::mutex> lock(job->mutex);
    job->window = nullptr;
    resolver = std::exchange(job->resolver, nullptr);
    session = std::exchange(job->session, nullptr);
  }
  if (resolver) WinHttpCloseHandle(resolver);
  if (session) WinHttpCloseHandle(session);
}

void Reply(const Resolution& resolution, Result* result) {
  if (resolution.error.empty()) {
    result->Success(Value(resolution.route));
  } else {
    // Never copy a target URL, PAC URL, headers, or Windows error data into Dart.
    result->Error(resolution.error, "Windows could not resolve the system proxy.");
  }
}
}  // namespace

class SystemProxy::Impl {
 public:
  explicit Impl(HWND window) : window_(window) {}
  ~Impl() {
    KillTimer(window_, kProxyTimer);
    for (auto& entry : pending_) Stop(entry.second.job);
    pending_.clear();
  }

  void Resolve(const std::string& requested, std::unique_ptr<Result> result) {
    const std::wstring url = Wide(requested);
    URL_COMPONENTS parts{};
    parts.dwStructSize = sizeof(parts);
    parts.dwHostNameLength = static_cast<DWORD>(-1);
    parts.dwUserNameLength = static_cast<DWORD>(-1);
    parts.dwPasswordLength = static_cast<DWORD>(-1);
    if (url.empty() || !WinHttpCrackUrl(url.c_str(), 0, 0, &parts) ||
        parts.nScheme != INTERNET_SCHEME_HTTPS || parts.dwHostNameLength == 0 ||
        parts.dwUserNameLength != 0 || parts.dwPasswordLength != 0) {
      Reply({{}, "system_proxy_invalid"}, result.get());
      return;
    }
    CurrentProxy config;
    if (!WinHttpGetIEProxyConfigForCurrentUser(&config.value)) {
      Reply({{}, "system_proxy_unavailable"}, result.get());
      return;
    }
    const std::wstring automatic = config.value.lpszAutoConfigUrl
        ? config.value.lpszAutoConfigUrl : L"";
    const std::wstring proxy = config.value.lpszProxy ? config.value.lpszProxy : L"";
    Resolution fallback{"DIRECT", {}};
    if (!proxy.empty()) {
      const std::wstring host(parts.lpszHostName, parts.dwHostNameLength);
      if (!config.value.lpszProxyBypass ||
          !Bypasses(config.value.lpszProxyBypass, host, parts.nPort)) {
        fallback = StaticProxy(proxy);
      }
    }
    // Match Windows' order: enabled WPAD, configured PAC, then static settings.
    // No detected configuration permits fallback; a broken discovered script
    // remains an error rather than unexpectedly bypassing its routing policy.
    if (automatic.empty() && !config.value.fAutoDetect) {
      Reply(fallback, result.get());
      return;
    }
    Begin(url, automatic, config.value.fAutoDetect != FALSE, fallback,
          GetTickCount64() + kDeadlineMs, std::move(result));
  }

  bool HandleMessage(UINT message, WPARAM wparam) {
    if (message == kProxyComplete) {
      Collect(static_cast<UINT_PTR>(wparam));
      return true;
    }
    if (message != WM_TIMER || wparam != kProxyTimer) return false;
    std::vector<UINT_PTR> ids;
    ids.reserve(pending_.size());
    for (const auto& entry : pending_) ids.push_back(entry.first);
    for (const auto id : ids) Collect(id);
    return true;
  }

 private:
  struct Pending {
    std::shared_ptr<Job> job;
    std::unique_ptr<Result> result;
    ULONGLONG deadline;
    Resolution fallback;
  };

  void Begin(const std::wstring& url, const std::wstring& automatic,
             bool detect_stage, const Resolution& fallback,
             ULONGLONG deadline, std::unique_ptr<Result> result) {
    if (GetTickCount64() >= deadline) {
      Reply({{}, "system_proxy_timeout"}, result.get());
      return;
    }
    if (pending_.size() >= 16) {
      Reply({{}, "system_proxy_unavailable"}, result.get());
      return;
    }
    const auto job = std::make_shared<Job>();
    job->window = window_;
    job->id = next_job_id.fetch_add(1);
    job->detect_stage = detect_stage;
    job->url = url;
    job->automatic_url = automatic;
    job->session = WinHttpOpen(L"DuoMonitor/1.6.0", WINHTTP_ACCESS_TYPE_NO_PROXY,
        WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, WINHTTP_FLAG_ASYNC);
    if (!job->session) {
      Reply({{}, "system_proxy_unavailable"}, result.get());
      return;
    }
    WinHttpSetTimeouts(job->session, 4000, 4000, 4000, 4000);
    const auto previous = WinHttpSetStatusCallback(job->session, ProxyCallback,
        WINHTTP_CALLBACK_FLAG_REQUEST_ERROR |
        WINHTTP_CALLBACK_FLAG_GETPROXYFORURL_COMPLETE |
        WINHTTP_CALLBACK_FLAG_HANDLES, 0);
    if (previous == WINHTTP_INVALID_STATUS_CALLBACK ||
        WinHttpCreateProxyResolver(job->session, &job->resolver) != ERROR_SUCCESS) {
      Stop(job);
      Reply({{}, "system_proxy_unavailable"}, result.get());
      return;
    }
    auto retained = new std::shared_ptr<Job>(job);
    DWORD_PTR context = reinterpret_cast<DWORD_PTR>(retained);
    if (!WinHttpSetOption(job->resolver, WINHTTP_OPTION_CONTEXT_VALUE,
                         &context, sizeof(context))) {
      delete retained;
      Stop(job);
      Reply({{}, "system_proxy_unavailable"}, result.get());
      return;
    }
    auto& options = job->options;
    options.dwFlags = WINHTTP_AUTOPROXY_RUN_OUTPROCESS_ONLY;
    if (detect_stage) {
      options.dwFlags |= WINHTTP_AUTOPROXY_AUTO_DETECT;
      options.dwAutoDetectFlags = WINHTTP_AUTO_DETECT_TYPE_DHCP |
                                  WINHTTP_AUTO_DETECT_TYPE_DNS_A;
    } else {
      options.dwFlags |= WINHTTP_AUTOPROXY_CONFIG_URL;
      options.lpszAutoConfigUrl = job->automatic_url.c_str();
    }
    // Do not automatically disclose the user's credentials to a PAC host.
    options.fAutoLogonIfChallenged = FALSE;
    pending_.emplace(job->id, Pending{job, std::move(result), deadline, fallback});
    const DWORD started = WinHttpGetProxyForUrlEx(job->resolver, job->url.c_str(),
                                                 &options, context);
    if (detect_stage && started == ERROR_WINHTTP_AUTODETECTION_FAILED) {
      Advance(job->id);
    } else if (started != ERROR_IO_PENDING ||
               !SetTimer(window_, kProxyTimer, 200, nullptr)) {
      Finish(job->id, {{}, "system_proxy_autoconfig_failed"});
    }
  }

  void Collect(UINT_PTR id) {
    const auto entry = pending_.find(id);
    if (entry == pending_.end()) return;
    bool complete = false;
    Resolution outcome;
    {
      std::lock_guard<std::mutex> lock(entry->second.job->mutex);
      complete = entry->second.job->complete;
      if (complete) outcome = entry->second.job->outcome;
    }
    if (complete) {
      if (outcome.error == "autodetect_not_found") {
        Advance(id);
      } else {
        Finish(id, outcome);
      }
    } else if (GetTickCount64() >= entry->second.deadline) {
      Finish(id, {{}, "system_proxy_timeout"});
    }
  }

  void Advance(UINT_PTR id) {
    const auto entry = pending_.find(id);
    if (entry == pending_.end()) return;
    // A fresh job owns the next resolver so a closing callback from the WPAD
    // handle can never write into the state of the configured PAC request.
    Pending previous = std::move(entry->second);
    pending_.erase(entry);
    Stop(previous.job);
    if (pending_.empty()) KillTimer(window_, kProxyTimer);
    if (previous.job->automatic_url.empty()) {
      Reply(previous.fallback, previous.result.get());
    } else {
      Begin(previous.job->url, previous.job->automatic_url, false,
            previous.fallback, previous.deadline, std::move(previous.result));
    }
  }

  void Finish(UINT_PTR id, const Resolution& outcome) {
    const auto entry = pending_.find(id);
    if (entry == pending_.end()) return;
    Stop(entry->second.job);
    auto result = std::move(entry->second.result);
    pending_.erase(entry);
    if (pending_.empty()) KillTimer(window_, kProxyTimer);
    Reply(outcome, result.get());
  }

  HWND window_;
  std::map<UINT_PTR, Pending> pending_;
};

SystemProxy::SystemProxy(HWND window) : impl_(std::make_unique<Impl>(window)) {}
SystemProxy::~SystemProxy() = default;

void SystemProxy::Resolve(const std::string& url, std::unique_ptr<Result> result) {
  impl_->Resolve(url, std::move(result));
}

bool SystemProxy::HandleMessage(UINT message, WPARAM wparam, LPARAM lparam) {
  return impl_->HandleMessage(message, wparam);
}
