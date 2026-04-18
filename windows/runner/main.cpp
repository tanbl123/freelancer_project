#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"
#include "app_links/app_links_plugin_c_api.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // ── Single-instance deep-link forwarding ──────────────────────────────────
  // When Windows opens the app via our custom URI scheme (OAuth callback),
  // it launches a brand-new process with the URI as argv[1].  If the app is
  // already running we just forward that URI to the existing window via
  // WM_COPYDATA (handled by the app_links plugin) and exit immediately so the
  // user never sees a second window flash open.
  {
    HWND existingHwnd = ::FindWindow(L"FLUTTER_RUNNER_WIN32_WINDOW",
                                     L"freelancer_project");
    if (existingHwnd != nullptr) {
      // SendAppLink() reads argv[1], validates the URI scheme, wraps it in a
      // COPYDATASTRUCT and posts WM_COPYDATA to the target window.  The
      // app_links plugin on the receiving end fires it into the Dart stream.
      SendAppLink(existingHwnd);
      ::SetForegroundWindow(existingHwnd);
      ::CoUninitialize();
      return EXIT_SUCCESS;
    }
  }
  // ─────────────────────────────────────────────────────────────────────────

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"freelancer_project", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
