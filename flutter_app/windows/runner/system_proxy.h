#ifndef RUNNER_SYSTEM_PROXY_H_
#define RUNNER_SYSTEM_PROXY_H_

#include <windows.h>
#include <flutter/encodable_value.h>
#include <flutter/method_result.h>

#include <memory>
#include <string>

// Reads the current user's active system proxy on every request. PAC/WPAD runs
// asynchronously in WinHTTP and is cancelled after six seconds or on shutdown.
class SystemProxy {
 public:
  explicit SystemProxy(HWND window);
  ~SystemProxy();

  void Resolve(
      const std::string& url,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  bool HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);

 private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};

#endif  // RUNNER_SYSTEM_PROXY_H_
