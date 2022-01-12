//
//  Copyright 2021 Daniel Müllenborn
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

#if os(Windows)
  import WinSDK
#endif

private var cachedTerminalWidth: Int = 0
public func terminalWidth() -> Int {
  if cachedTerminalWidth > 0 { return cachedTerminalWidth }
  #if os(Windows)
    var csbi: CONSOLE_SCREEN_BUFFER_INFO = CONSOLE_SCREEN_BUFFER_INFO()
    if GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &csbi) {
      let width = Int(csbi.srWindow.Right - csbi.srWindow.Left)
      cachedTerminalWidth = width
    } else {
      cachedTerminalWidth = 80
    }
  #elseif os(iOS)
    cachedTerminalWidth = 80
  #else
    // First try to get from environment.
    if let columns = ProcessInfo.processInfo.environment["COLUMNS"], let width = Int(columns) {
      cachedTerminalWidth = width
    } else {
      var ws = winsize()
      if ioctl(1, UInt(TIOCGWINSZ), &ws) == 0 { cachedTerminalWidth = Int(ws.ws_col) - 1 }
    }
  #endif
  if cachedTerminalWidth < 0 { cachedTerminalWidth = 150 }
  return cachedTerminalWidth
}

public func start(_ command: String) {
  #if os(Windows)
    let _ = ShellExecuteW(nil, "open".wide, command.wide, nil, nil, 8)
  #elseif os(macOS)
    if #available(macOS 10.13, *) {
      do { try Process.run("/usr/bin/open", arguments: [command]) } catch {}
    }
  #endif
}
#if os(Windows) || os(Linux)
  extension FileManager {
    static func transientDirectory(url: (URL) throws -> Void) throws {
      let fm = FileManager.default
      let id = String(UUID().uuidString.prefix(8))
      let directory = fm.temporaryDirectory.appendingPathComponent(id, isDirectory: true)
      try fm.createDirectory(at: directory, withIntermediateDirectories: false)
      try url(directory)
      try fm.removeItem(at: directory)
    }
  }

  extension URL {
    var windowsPath: String { path.replacingOccurrences(of: "/", with: "\\") }

    static public func temporaryFile() -> URL {
      let fm = FileManager.default
      let id = String(UUID().uuidString.prefix(8))
      return fm.temporaryDirectory.appendingPathComponent(id)
    }

    public func removeItem() throws { try FileManager.default.removeItem(at: self) }
  }
#endif

extension URL: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) { self.init(fileURLWithPath: value) }
}

extension String {
  public func leftpad(length: Int, character: Character = " ") -> String {
    var outString: String = self
    let extraLength = length - outString.count
    var i = 0
    while i < extraLength {
      outString.insert(character, at: outString.startIndex)
      i += 1
    }
    return outString
  }
}

extension Collection where Self.Iterator.Element: RandomAccessCollection {
  @_alwaysEmitIntoClient public func transposed() -> [[Self.Iterator.Element.Iterator.Element]] {
    guard let firstRow = self.first else { return [] }
    return firstRow.indices.map { index in self.map { $0[index] } }
  }
}

@_alwaysEmitIntoClient public func seek(
  goal: Double, _ range: ClosedRange<Double> = 0...1, tolerance: Double = 0.0001,
  maxIterations: Int = 100, _ f: (Double) -> Double
) -> Double {
  var a = range.lowerBound
  var b = range.upperBound
  for _ in 0..<maxIterations {
    let c = (a + b) / 2
    let fc = f(c)
    let fa = f(a)
    if fc == goal || (b - a) / 2 < tolerance { return c }
    if (fc < goal && fa < goal) || (fc > goal && fa > goal) { a = c } else { b = c }
  }
  return Double.nan
}

@_alwaysEmitIntoClient public func concurrentSeek(
  goal: Double, _ range: ClosedRange<Double> = 0...1, tolerance: Double = 0.0001,
  maxIterations: Int = 100, _ f: (Double) -> Double
) -> Double {
  var x = [range.lowerBound, 0.0, range.upperBound]
  var y = [0.0, 0.0]
  for _ in 0..<maxIterations {
    x[1] = (x[0] + x[2]) / 2
    DispatchQueue.concurrentPerform(iterations: 2) { i in y[i] = f(x[i]) }
    if y[1] == goal || (x[2] - x[0]) / 2 < tolerance { return x[1] }
    if (y[1] < goal && y[0] < goal) || (y[1] > goal && y[0] > goal) {
      x[0] = x[1]
    } else {
      x[2] = x[1]
    }
  }
  return Double.nan
}

// Fitting y = a0 + a1*x
// least squares method
// a0 =  (sumX - sumY) * sumXY / (sumX * sumX - n * sumXY)
// a1 =  (sumX * sumY - n * sumXY) / (sumX * sumX - n * sumXX)
@_alwaysEmitIntoClient public func linearFit(x: [Double], y: [Double]) -> (Double) -> Double {
  var sumX: Double = 0
  var sumY: Double = 0
  var sumXY: Double = 0
  var sumXX: Double = 0
  let count = min(x.count, y.count)
  for i in 0..<count {
    sumX += x[i]
    sumY += y[i]
    sumXX += x[i] * x[i]
    sumXY += x[i] * y[i]
  }
  let a0 = (sumX - sumY) * sumXY / (sumX * sumX - Double(count) * sumXY)
  let a1 = (sumX * sumY - Double(count) * sumXY) / (sumX * sumX - Double(count) * sumXX)

  return { value in a0 + a1 * value }
}
#if swift(>=5.4)
  public typealias XY = SIMD2<Double>

  extension Sequence where Element == XY {
    public func plot(_ terminal: Gnuplot.Terminal) -> Data? {
      try? Gnuplot(xys: self, style: .points)(terminal)
    }
  }

  @inlinable public func evaluate(
    inDomain range: ClosedRange<Double>, step: Double, f: (Double) -> Double
  ) -> [[Double]] {
    stride(from: range.lowerBound, through: range.upperBound, by: step).map { [$0, f($0)] }
  }
#endif
extension Comparable {
  public mutating func clamp(to limits: ClosedRange<Self>) {
    self = min(max(self, limits.lowerBound), limits.upperBound)
  }
  public func clamped(to limits: ClosedRange<Self>) -> Self {
    min(max(self, limits.lowerBound), limits.upperBound)
  }
}

/// Sorts the given arguments in ascending order, and returns the middle value.
///
///     // Values clamped to `0...100`
///     median(0, .min, 100)  //-> 0
///     median(0, .max, 100)  //-> 100
///
/// - Parameters:
///   - x: A value to compare.
///   - y: Another value to compare.
///   - z: A third value to compare.
///
/// - Returns: The middle value.
@_alwaysEmitIntoClient public func median<T: Comparable>(_ x: T, _ y: T, _ z: T) -> T {
  var (x, y, z) = (x, y, z)
  // Compare (and swap) each pair of adjacent variables.
  if x > y { (x, y) = (y, x) }
  if y > z {
    (y, z) = (z, y)
    if x > y { (x, y) = (y, x) }
  }
  // Now `x` has the least value, and `z` has the greatest value.
  return y
}

/// Sorts the given arguments in ascending order, and returns the middle value.
///
///     // Values clamped to `0.0...1.0`
///     median(0.0, -.pi, 1.0)  //-> 0.0
///     median(0.0, +.pi, 1.0)  //-> 1.0
///
/// The sorted values will be totally ordered, including signed zeros and NaNs.
///
/// - Parameters:
///   - x: A value to compare.
///   - y: Another value to compare.
///   - z: A third value to compare.
///
/// - Returns: The middle value.
@_alwaysEmitIntoClient public func median<T: FloatingPoint>(_ x: T, _ y: T, _ z: T) -> T {
  var (x, y, z) = (x, y, z)
  // Compare (and swap) each pair of adjacent variables.
  if !x.isTotallyOrdered(belowOrEqualTo: y) { (x, y) = (y, x) }
  if !y.isTotallyOrdered(belowOrEqualTo: z) {
    (y, z) = (z, y)
    if !x.isTotallyOrdered(belowOrEqualTo: y) { (x, y) = (y, x) }
  }
  // Now `x` has the least value, and `z` has the greatest value.
  return y
}

/// Sorts the given arguments in ascending order, and returns the middle value,
/// or the arithmetic mean of two middle values.
///
///     median(1, 2)            //-> 1.5
///     median(1, 2, 4)         //-> 2
///     median(1, 2, 4, 8)      //-> 3
///     median(1, 2, 4, 8, 16)  //-> 4
///
/// The sorted values will be totally ordered, including signed zeros and NaNs.
///
/// - Parameters:
///   - x: A value to compare.
///   - y: Another value to compare.
///   - rest: Zero or more additional values.
///
/// - Returns: The middle value, or the arithmetic mean of two middle values.
@_alwaysEmitIntoClient public func median<T: FloatingPoint>(_ x: T, _ y: T, _ rest: T...) -> T {
  func _mean(_ a: T, _ b: T) -> T {
    (a.sign == b.sign)  // Avoid overflowing to infinity, by choosing to
      ? a + ((b - a) / 2)  // ? either advance by half the distance,
      : (a + b) / 2  // : or use the sum divided by the count.
  }
  guard !rest.isEmpty else { return _mean(x, y) }

  var values = ContiguousArray<T>()
  values.reserveCapacity(2 + rest.count)
  values.append(x)
  values.append(y)
  values.append(contentsOf: rest)
  values.sort(by: { !$1.isTotallyOrdered(belowOrEqualTo: $0) })

  let index = (values.endIndex - 1) / 2
  if values.count.isMultiple(of: 2) {
    return _mean(values[index], values[index + 1])
  } else {
    return values[index]
  }
}
#if os(Linux)
  import CZLib

  extension Data {
    /// Whether the receiver is compressed in gzip format.
    public var isGzipped: Bool { self.starts(with: [0x1f, 0x8b]) }
    /// Create a new `Data` instance by compressing the receiver using zlib.
    /// Throws an error if compression failed.
    ///
    /// - Parameter level: Compression level.
    /// - Returns: Gzip-compressed `Data` instance.
    /// - Throws: `GzipError`
    public func gzipped(level: CompressionLevel = .defaultCompression) -> Data {
      guard !self.isEmpty else { return Data() }
      var stream = z_stream()
      var status: Int32
      status = deflateInit2_(
        &stream, level.rawValue, Z_DEFLATED, MAX_WBITS + 16, MAX_MEM_LEVEL, Z_DEFAULT_STRATEGY,
        ZLIB_VERSION, Int32(DataSize.stream))
      guard status == Z_OK else { return self }
      var data = Data(capacity: DataSize.chunk)
      repeat {
        if Int(stream.total_out) >= data.count { data.count += DataSize.chunk }
        let inputCount = self.count
        let outputCount = data.count
        self.withUnsafeBytes { (inputPointer: UnsafeRawBufferPointer) in
          stream.next_in = UnsafeMutablePointer<Bytef>(
            mutating: inputPointer.bindMemory(to: Bytef.self).baseAddress!
          ).advanced(by: Int(stream.total_in))
          stream.avail_in = uint(inputCount) - uInt(stream.total_in)
          data.withUnsafeMutableBytes { (outputPointer: UnsafeMutableRawBufferPointer) in
            stream.next_out = outputPointer.bindMemory(to: Bytef.self).baseAddress!.advanced(
              by: Int(stream.total_out))
            stream.avail_out = uInt(outputCount) - uInt(stream.total_out)
            status = deflate(&stream, Z_FINISH)
            stream.next_out = nil
          }
          stream.next_in = nil
        }
      } while stream.avail_out == 0
      guard deflateEnd(&stream) == Z_OK, status == Z_STREAM_END else { return self }
      data.count = Int(stream.total_out)
      return data
    }
  }

  private enum DataSize {
    static let chunk = 1 << 14
    static let stream = MemoryLayout<z_stream>.size
  }

  /// Compression level whose rawValue is based on the zlib's constants.
  public struct CompressionLevel: RawRepresentable {
    /// Compression level in the range of `0` (no compression) to `9` (maximum compression).
    public let rawValue: Int32
    public static let noCompression = CompressionLevel(Z_NO_COMPRESSION)
    public static let bestSpeed = CompressionLevel(Z_BEST_SPEED)
    public static let bestCompression = CompressionLevel(Z_BEST_COMPRESSION)
    public static let defaultCompression = CompressionLevel(Z_DEFAULT_COMPRESSION)
    public init(rawValue: Int32) { self.rawValue = rawValue }
    public init(_ rawValue: Int32) { self.rawValue = rawValue }
  }
#endif
