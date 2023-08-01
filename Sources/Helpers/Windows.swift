#if os(Windows)
  import CRT
  import WinSDK
  import func WinSDK.MessageBoxW
  import let WinSDK.MB_OK
  import struct WinSDK.UINT

  /// Internal initializer to create a Swift String from a UTF-16 encoded array.
  extension String {
    internal init(from utf16: [UInt16]) {
      self = utf16.withUnsafeBufferPointer {
        String(decodingCString: $0.baseAddress!, as: UTF16.self)
      }
    }
  }

  extension String {
    /// Returns the wide (UTF-16) representation of the String as an array of UInt16.
    public var wide: [UInt16] {
      return [UInt16](from: self)
    }
  }

  extension Array where Element == UInt16 {
    /// Internal initializer to create a UTF-16 encoded array from a Swift String.
    internal init(from string: String) {
      self = string.withCString(encodedAs: UTF16.self) { buffer in
        [UInt16](unsafeUninitializedCapacity: string.utf16.count + 1) {
          wcscpy_s($0.baseAddress, $0.count, buffer)
          $1 = $0.count
        }
      }
    }
  }

  /// Sets the content of the clipboard to the given text.
  ///
  /// - Parameter text: The text to be copied to the clipboard.
  public func setClipboard(_ text: String) {
    let size = text.utf16.count * MemoryLayout<UInt16>.size
    guard let hMem = GlobalAlloc(UINT(GHND), SIZE_T(size + 1))
    else { return }
    text.withCString(encodedAs: UTF16.self) {
      let dst = GlobalLock(hMem)
      memcpy(dst, $0, size)
      GlobalUnlock(hMem)
    }
    if OpenClipboard(nil) {
      EmptyClipboard()
      SetClipboardData(UINT(CF_UNICODETEXT), hMem)
      CloseClipboard()
    }
  }

  /// Shows a message box with the given text and caption.
  ///
  /// - Parameters:
  ///   - text: The text to be displayed in the message box.
  ///   - caption: The caption of the message box.
  public func MessageBox(text: String, caption: String) {
    MessageBoxW(nil, text.wide, caption.wide, UINT(MB_OK))
  }

  /// Returns the current directory path.
  ///
  /// - Returns: The current directory path as a String.
  public func currentDirectoryPath() -> String {
    let dwLength: DWORD = GetCurrentDirectoryW(0, nil)
    var szDirectory: [WCHAR] = [WCHAR](repeating: 0, count: Int(dwLength + 1))

    GetCurrentDirectoryW(dwLength, &szDirectory)
    return String(decodingCString: &szDirectory, as: UTF16.self)
  }

  /// Shows a file dialog and returns the selected file path.
  ///
  /// - Returns: The selected file path as a String or nil if no file was selected.
  public func FileDialog() -> String? {
    var strFile = "".utf8CString

    var ofn = OPENFILENAMEA()

    strFile.withUnsafeMutableBufferPointer {
      ofn.lpstrFile = $0.baseAddress
      ofn.lpstrFile[0] = 0
    }

    ofn.nFilterIndex = 1
    ofn.nMaxFile = 240
    ofn.Flags = DWORD(OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST)
    ofn.lStructSize = UInt32(MemoryLayout<OPENFILENAMEA>.size)

    return GetOpenFileNameA(&ofn) ? String(cString: ofn.lpstrFile) : nil
  }

  /// Clears the console screen by filling it with spaces.
  public func ClearScreen() {
    let handle = GetStdHandle(STD_OUTPUT_HANDLE)
    var cursor = CONSOLE_CURSOR_INFO(dwSize: 1, bVisible: false)
    SetConsoleCursorInfo(handle, &cursor)
    var info = CONSOLE_SCREEN_BUFFER_INFO()
    GetConsoleScreenBufferInfo(handle, &info)
    var count = DWORD()
    FillConsoleOutputCharacterW(handle, WCHAR(32), DWORD(info.dwSize.X * info.dwSize.X), COORD(X: 0, Y: 0), &count)
    SetConsoleCursorPosition(handle, COORD(X: 0, Y: 0))
  }
#else
  /// Clears the console screen by printing ANSI escape codes to move the cursor to the top-left corner and clear the screen.
  public func ClearScreen() {
    print("\u{1b}[2J", "\u{1b}[0;0H", terminator: "")
  }
#endif
