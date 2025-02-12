#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

  // Method channel for drag events
  std::unique_ptr<flutter::MethodChannel<>> drag_channel_;

  UINT_PTR drag_timer_ = 0;  // Add this line

  // Add these methods:
  void StartDrag(const std::vector<std::wstring>& filePaths);
  static LRESULT CALLBACK DragDropHookProc(int nCode, WPARAM wParam, LPARAM lParam);

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Handle to the drag-drop event hook
  HWINEVENTHOOK drag_hook_ = nullptr;

  HWND window_handle_ = nullptr; // Add this line

  // Add these members:
  HHOOK mouse_hook_;
  bool is_dragging_;
  std::vector<std::wstring> drag_files_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
