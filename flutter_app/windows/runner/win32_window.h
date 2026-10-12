#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#include <windows.h>

#include <functional>
#include <memory>
#include <string>

// A class abstraction for a high DPI-aware Win32 Window. Intended to be
// inherited from by classes that wish to specialize with custom
// rendering and input handling
class Win32Window {
 public:
  struct Point {
    int x;
    int y;
    Point(int x, int y) : x(x), y(y) {}
  };

  struct Size {
    unsigned int width;
    unsigned int height;
    Size(unsigned int width, unsigned int height)
        : width(width), height(height) {}
  };

  // Physical screen bounds and the DPI factor at the time they were captured.
  struct Bounds {
    RECT rect{};
    std::wstring display_id;
    double scale = 1.0;
  };

  Win32Window();
  virtual ~Win32Window();

  // Creates a win32 window with |title| that is positioned and sized using
  // |origin| and |size|. Origin uses physical screen coordinates; size uses
  // logical desktop pixels and is scaled for the origin's display. The window
  // is invisible until
  // |Show| is called. Returns true if the window was created successfully.
  bool Create(const std::wstring& title, const Point& origin, const Size& size);

  // Show the current window. Returns true if the window was successfully shown.
  bool Show();

  // Release OS resources associated with window.
  void Destroy();

  // Inserts |content| into the window tree.
  void SetChildContent(HWND content);

  // Returns the backing Window handle to enable clients to set icon and other
  // window properties. Returns nullptr if the window has been destroyed.
  HWND GetHandle();

  // If true, closing this window will quit the application.
  void SetQuitOnClose(bool quit_on_close);

  // Return a RECT representing the bounds of the current client area.
  RECT GetClientArea();

  Bounds GetWindowBounds() const;
  void ApplyWindowBounds(const Bounds& bounds);
  void ClampToVisibleWorkArea();
  bool SetAlwaysOnTop(bool enabled);
  bool SetOpacity(double opacity);
  void SetSettingsMode(bool enabled);
  bool BeginMoveOrResize(int hit_test);

 protected:
  // Processes and route salient window messages for mouse handling,
  // size change and DPI. Delegates handling of these to member overloads that
  // inheriting classes can handle.
  virtual LRESULT MessageHandler(HWND window,
                                 UINT const message,
                                 WPARAM const wparam,
                                 LPARAM const lparam) noexcept;

  // Called when CreateAndShow is called, allowing subclass window-related
  // setup. Subclasses should return false if setup fails.
  virtual bool OnCreate();

  // Called when Destroy is called.
  virtual void OnDestroy();

 private:
  friend class WindowClassRegistrar;

  // OS callback called by message pump. Handles the WM_NCCREATE message which
  // is passed when the non-client area is being created and enables automatic
  // non-client DPI scaling so that the non-client area automatically
  // responds to changes in DPI. All other messages are handled by
  // MessageHandler.
  static LRESULT CALLBACK WndProc(HWND const window,
                                  UINT const message,
                                  WPARAM const wparam,
                                  LPARAM const lparam) noexcept;

  // Retrieves a class instance pointer for |window|
  static Win32Window* GetThisFromHandle(HWND const window) noexcept;

  // Let the parent own edge resizing even where the Flutter child covers it.
  static LRESULT CALLBACK ChildSubclassProc(HWND window, UINT message,
                                           WPARAM wparam, LPARAM lparam,
                                           UINT_PTR subclass_id,
                                           DWORD_PTR reference_data);
  LRESULT ResizeHitTest(LPARAM screen_point) const;
  bool ApplyOpacity();

  // Suppress system frame painting and refresh the native theme preference.
  static void UpdateTheme(HWND const window);

  bool quit_on_close_ = false;

  // window handle for top level window.
  HWND window_handle_ = nullptr;

  // window handle for hosted content.
  HWND child_content_ = nullptr;
  bool settings_mode_ = false;
  double panel_opacity_ = 0.96;
  Bounds panel_bounds_;
};

#endif  // RUNNER_WIN32_WINDOW_H_
