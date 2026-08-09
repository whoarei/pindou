#include "flutter_window.h"

#include <commdlg.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <array>
#include <cstdint>
#include <memory>
#include <optional>
#include <string>
#include <thread>
#include <utility>
#include <variant>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"

namespace {

constexpr UINT kFileDialogCompleteMessage = WM_APP + 0x421;
constexpr char kFilesChannel[] = "com.pindou.bead_pattern_generator/files";

struct FileDialogOutcome {
  std::wstring path;
  DWORD error = 0;
};

struct FileDialogCompletion {
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result;
  FileDialogOutcome outcome;
};

std::wstring Utf16FromUtf8(const std::string& value) {
  if (value.empty()) {
    return std::wstring();
  }
  const int target_length = MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
      static_cast<int>(value.size()), nullptr, 0);
  if (target_length <= 0) {
    return std::wstring();
  }
  std::wstring output(target_length, L'\0');
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                          static_cast<int>(value.size()), output.data(),
                          target_length) == 0) {
    return std::wstring();
  }
  return output;
}

FileDialogOutcome ShowFileDialog(HWND owner, bool save,
                                 const std::wstring& suggested_name) {
  std::array<wchar_t, 32768> path_buffer{};
  if (!suggested_name.empty()) {
    wcsncpy_s(path_buffer.data(), path_buffer.size(), suggested_name.c_str(),
              _TRUNCATE);
  }

  constexpr wchar_t kImageFilter[] =
      L"Images (*.jpg;*.jpeg;*.png)\0*.jpg;*.jpeg;*.png\0"
      L"All files (*.*)\0*.*\0";
  constexpr wchar_t kJpegFilter[] =
      L"JPEG image (*.jpg)\0*.jpg\0All files (*.*)\0*.*\0";

  OPENFILENAMEW dialog{};
  dialog.lStructSize = sizeof(dialog);
  dialog.hwndOwner = owner;
  dialog.lpstrFile = path_buffer.data();
  dialog.nMaxFile = static_cast<DWORD>(path_buffer.size());
  dialog.lpstrFilter = save ? kJpegFilter : kImageFilter;
  dialog.nFilterIndex = 1;
  dialog.lpstrTitle = save ? L"Export bead pattern" : L"Select JPG or PNG";
  dialog.Flags = OFN_EXPLORER | OFN_PATHMUSTEXIST | OFN_NOCHANGEDIR;
  if (save) {
    dialog.Flags |= OFN_OVERWRITEPROMPT;
    dialog.lpstrDefExt = L"jpg";
  } else {
    dialog.Flags |= OFN_FILEMUSTEXIST | OFN_HIDEREADONLY;
  }

  const BOOL selected =
      save ? GetSaveFileNameW(&dialog) : GetOpenFileNameW(&dialog);
  if (selected) {
    return FileDialogOutcome{path_buffer.data(), 0};
  }
  return FileDialogOutcome{L"", CommDlgExtendedError()};
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  files_channel_ = std::make_unique<
      flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), kFilesChannel,
      &flutter::StandardMethodCodec::GetInstance());
  files_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<
                 flutter::MethodResult<flutter::EncodableValue>> result) {
        const bool is_open = call.method_name() == "pickImage";
        const bool is_save = call.method_name() == "pickJpegSavePath";
        if (!is_open && !is_save) {
          result->NotImplemented();
          return;
        }
        if (file_dialog_open_) {
          result->Error("DIALOG_BUSY", "Another file dialog is already open.");
          return;
        }

        std::wstring suggested_name;
        if (is_save && call.arguments() != nullptr) {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments != nullptr) {
            const auto name = arguments->find(
                flutter::EncodableValue(std::string("fileName")));
            if (name != arguments->end()) {
              const auto* value = std::get_if<std::string>(&name->second);
              if (value != nullptr) {
                suggested_name = Utf16FromUtf8(*value);
              }
            }
          }
        }

        file_dialog_open_ = true;
        const HWND owner = GetHandle();
        auto* raw_result = result.release();
        std::thread([owner, raw_result, is_save,
                     suggested_name = std::move(suggested_name)]() mutable {
          auto completion = std::make_unique<FileDialogCompletion>();
          completion->result.reset(raw_result);
          completion->outcome = ShowFileDialog(owner, is_save, suggested_name);
          if (!IsWindow(owner) ||
              !PostMessage(owner, kFileDialogCompleteMessage, 0,
                           reinterpret_cast<LPARAM>(completion.get()))) {
            return;
          }
          completion.release();
        }).detach();
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() { this->Show(); });
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  files_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  // WM_APP is also used internally by the Flutter embedder. Consume our
  // private completion message before offering messages to Flutter, otherwise
  // it may interpret lparam as one of its own task pointers.
  if (message == kFileDialogCompleteMessage) {
    std::unique_ptr<FileDialogCompletion> completion(
        reinterpret_cast<FileDialogCompletion*>(lparam));
    file_dialog_open_ = false;
    if (completion->outcome.error != 0) {
      completion->result->Error(
          "FILE_DIALOG_ERROR", "The Windows file dialog failed.",
          flutter::EncodableValue(
              static_cast<int32_t>(completion->outcome.error)));
    } else if (completion->outcome.path.empty()) {
      completion->result->Success();
    } else {
      completion->result->Success(flutter::EncodableValue(
          Utf8FromUtf16(completion->outcome.path.c_str())));
    }
    return 0;
  }

  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
