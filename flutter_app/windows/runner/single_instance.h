#ifndef RUNNER_SINGLE_INSTANCE_H_
#define RUNNER_SINGLE_INSTANCE_H_

#include <windows.h>

#include <string>

// One application per Windows user and interactive session, independent of its
// executable directory. The mutex is acquired before Flutter or storage starts.
class SingleInstance {
 public:
  enum class StartResult { kPrimary, kForwarded, kError };

  // A different protocol namespace is useful for embedding and isolated native
  // checks. Application releases always use the stable default below.
  explicit SingleInstance(
      std::wstring protocol_namespace = L"CryptoFloat.SingleInstance.v1");
  ~SingleInstance();
  SingleInstance(const SingleInstance&) = delete;
  SingleInstance& operator=(const SingleInstance&) = delete;

  StartResult Start();
  bool AttachWindow(HWND window);
  void DetachWindow();

  static UINT ActivationMessage();

 private:
  static void CALLBACK OnActivation(void* context, BOOLEAN timed_out);

  HANDLE mutex_ = nullptr;
  HANDLE activation_event_ = nullptr;
  HANDLE activation_wait_ = nullptr;
  HWND window_ = nullptr;
  bool owns_mutex_ = false;
  std::wstring protocol_namespace_;
  std::wstring window_property_;
};

#endif  // RUNNER_SINGLE_INSTANCE_H_
