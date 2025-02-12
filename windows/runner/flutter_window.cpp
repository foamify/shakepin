#include "flutter_window.h"
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <shlobj_core.h>

#include <memory>

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "drag_drop_impl.h"

HWND g_flutter_window = nullptr;
bool g_is_moving_or_resizing = false; // Add this line

FlutterWindow::FlutterWindow(const flutter::DartProject &project)
    : project_(project) {}

FlutterWindow::~FlutterWindow()
{
  if (drag_timer_)
  {
    KillTimer(NULL, drag_timer_);
    drag_timer_ = 0;
  }
}

void CALLBACK DragTimerProc(HWND hwnd, UINT msg, UINT_PTR id, DWORD time)
{
  if (!(GetAsyncKeyState(VK_LBUTTON) & 0x8000))
  {
    FlutterWindow *flutter_window = reinterpret_cast<FlutterWindow *>(
        GetWindowLongPtr(g_flutter_window, GWLP_USERDATA));
    if (flutter_window && flutter_window->drag_channel_)
    {
      flutter_window->drag_channel_->InvokeMethod(
          "dragConclude",
          std::make_unique<flutter::EncodableValue>());
      KillTimer(NULL, id);
    }
  }
}

void CALLBACK HandleDragHook(
    HWINEVENTHOOK hook,
    DWORD event,
    HWND hwnd,
    LONG idObject,
    LONG idChild,
    DWORD dwEventThread,
    DWORD dwmsEventTime)
{
  // Handle move/size events first
  switch (event)
  {
  case EVENT_SYSTEM_MOVESIZESTART:
    g_is_moving_or_resizing = true;
    return;

  case EVENT_SYSTEM_MOVESIZEEND:
    g_is_moving_or_resizing = false;
    return;
  }

  // If we're currently moving/resizing, don't process other events
  if (g_is_moving_or_resizing)
  {
    return;
  }

  // Early filter conditions
  if (event >= EVENT_OBJECT_NAMECHANGE && event <= EVENT_OBJECT_ACCELERATORCHANGE ||
      event == DOF_EXECUTABLE ||
      event == DOF_DOCUMENT ||
      event == DOF_DIRECTORY ||
      event == DOF_MULTIPLE ||
      event == DOF_PROGMAN ||
      event == DOF_SHELLDATA)
  {
    return;
  }

  switch (event)
  {

  case EVENT_OBJECT_LOCATIONCHANGE:
  {
    if (idObject < 0 || !g_flutter_window)
    {
      break;
    }

    // Additional check for move/resize state
    if (g_is_moving_or_resizing)
    {
      break;
    }

    // Check if left mouse button is pressed, if not - ignore the event
    if (!(GetAsyncKeyState(VK_LBUTTON) & 0x8000))
    {
      break;
    }

    FlutterWindow *flutter_window = reinterpret_cast<FlutterWindow *>(
        GetWindowLongPtr(g_flutter_window, GWLP_USERDATA));
    if (!flutter_window || !flutter_window->drag_channel_)
    {
      break;
    }

    // Cancel existing timer if any
    if (flutter_window->drag_timer_)
    {
      KillTimer(NULL, flutter_window->drag_timer_);
    }

    // printf("Location changed. HWND: %p, idObject: %ld, idChild: %ld, Thread: %lu, Time: %lu\n",
    //        hwnd, idObject, idChild, dwEventThread, dwmsEventTime);

    // Set new timer to check left mouse button state every 100ms
    flutter_window->drag_timer_ = SetTimer(
        NULL,
        0,
        100,
        DragTimerProc);

    // Check both shift keys
    bool isShiftPressed = (GetAsyncKeyState(VK_LSHIFT) & 0x8000) ||
                          (GetAsyncKeyState(VK_RSHIFT) & 0x8000);

    flutter::EncodableMap args = flutter::EncodableMap();
    args[flutter::EncodableValue("hwnd")] = flutter::EncodableValue((int)((LONG_PTR)hwnd));
    args[flutter::EncodableValue("idObject")] = flutter::EncodableValue(idObject);
    args[flutter::EncodableValue("idChild")] = flutter::EncodableValue(idChild);
    args[flutter::EncodableValue("thread")] = flutter::EncodableValue((int)dwEventThread);
    args[flutter::EncodableValue("time")] = flutter::EncodableValue((int)dwmsEventTime);
    args[flutter::EncodableValue("isShiftPressed")] = flutter::EncodableValue(isShiftPressed);

    flutter_window->drag_channel_->InvokeMethod(
        "locationChange",
        std::make_unique<flutter::EncodableValue>(args));
  }
  break;
  }
}

void FlutterWindow::StartDrag(const std::vector<std::wstring>& filePaths) {
  drag_files_ = filePaths;
  is_dragging_ = true;

  // Create data object
  ShellDataObject* dataObj = new ShellDataObject(filePaths);
  
  // Start drag-drop operation
  DWORD dwEffect;
  HRESULT hr = SHDoDragDrop(
      nullptr,                // Optional window handle
      dataObj,               // IDataObject instance
      nullptr,               // Optional IDropSource instance
      DROPEFFECT_COPY,       // Allowed effects
      &dwEffect);            // Resultant effect

  is_dragging_ = false;
  dataObj->Release();

  // Send result back to Flutter
  if (drag_channel_) {
    flutter::EncodableMap args = flutter::EncodableMap();
    args[flutter::EncodableValue("result")] = flutter::EncodableValue((int)hr);
    args[flutter::EncodableValue("effect")] = flutter::EncodableValue((int)dwEffect);
    
    drag_channel_->InvokeMethod(
        "dragComplete",
        std::make_unique<flutter::EncodableValue>(args));
  }
}

bool FlutterWindow::OnCreate()
{
  if (!Win32Window::OnCreate())
  {
    return false;
  }

  window_handle_ = GetHandle();
  g_flutter_window = window_handle_;
  SetWindowLongPtr(window_handle_, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view())
  {
    return false;
  }

  flutter::MethodChannel<> channel(
      flutter_controller_->engine()->messenger(), "com.damywise.shakepin/clicks",
      &flutter::StandardMethodCodec::GetInstance());
  channel.SetMethodCallHandler(
      [](const flutter::MethodCall<> &call,
         std::unique_ptr<flutter::MethodResult<>> result)
      {
        if (call.method_name().compare("getClicks") == 0)
        {
          int clicks = GetAsyncKeyState(VK_LBUTTON) & 0x8000 ? 1 << 0 : 0;
          clicks |= GetAsyncKeyState(VK_RBUTTON) & 0x8000 ? 1 << 1 : 0;
          clicks |= GetAsyncKeyState(VK_MBUTTON) & 0x8000 ? 1 << 2 : 0;
          result->Success(flutter::EncodableValue(clicks));
        }
        else
        {
          result->NotImplemented();
        }
      });

  // Create drag channel
  drag_channel_ = std::make_unique<flutter::MethodChannel<>>(
      flutter_controller_->engine()->messenger(),
      "click.shakepin.macos/drop",
      &flutter::StandardMethodCodec::GetInstance());

  // Set up drag channel handler
  drag_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<>& call,
             std::unique_ptr<flutter::MethodResult<>> result) {
        if (call.method_name() == "startDrag") {
          if (auto* arguments = std::get_if<flutter::EncodableList>(call.arguments())) {
            std::vector<std::wstring> filePaths;
            for (const auto& arg : *arguments) {
              if (auto* path = std::get_if<std::string>(&arg)) {
                filePaths.push_back(std::wstring(path->begin(), path->end()));
              }
            }
            StartDrag(filePaths);
            result->Success();
          } else {
            result->Error("INVALID_ARGUMENTS", "Expected list of file paths");
          }
        } else {
          result->NotImplemented();
        }
      });

  // Install drag-drop hook
  drag_hook_ = SetWinEventHook(
      EVENT_MIN,
      EVENT_MAX,
      nullptr,
      HandleDragHook,
      0,
      0,
      WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS);

  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]()
                                                      { this->Show(); });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy()
{
  if (window_handle_)
  {
    SetWindowLongPtr(window_handle_, GWLP_USERDATA, 0);
    window_handle_ = nullptr;
    g_flutter_window = nullptr;
  }

  if (drag_hook_)
  {
    UnhookWinEvent(drag_hook_);
    drag_hook_ = nullptr;
  }

  if (flutter_controller_)
  {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept
{
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_)
  {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result)
    {
      return *result;
    }
  }

  switch (message)
  {
  case WM_FONTCHANGE:
    flutter_controller_->engine()->ReloadSystemFonts();
    break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
