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
  if let columns: String = ProcessInfo.processInfo.environment["COLUMNS"], let width = Int(columns) {
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
      let id = String(Int(Date().timeIntervalSince1970), radix: 36, uppercase: true)
      return fm.temporaryDirectory.appendingPathComponent(String(id.suffix(5)))
    }

    public func removeItem() throws { try FileManager.default.removeItem(at: self) }
  }
#endif

extension Date: ExpressibleByStringLiteral {
  public init(stringLiteral: String) { self.init(Substring(stringLiteral)) }
  public init(_ dateString: Substring) {
    let values: [Int32] = dateString.split(
      maxSplits: 6, 
      omittingEmptySubsequences: true, 
      whereSeparator: {!$0.isWholeNumber}
    ).compactMap { Int32($0) }
    var t = time_t()
    time(&t)
    #if os(Windows)
    var info = tm()
    localtime_s(&info, &t)
    #else
    var info = localtime(&t)!.pointee
    #endif
    info.tm_year = values[0] - 1900
    info.tm_mon = values[1] - 1
    info.tm_mday = values[2]
    if values.count > 4 {
      info.tm_hour = values[3]
      info.tm_min = values[4]
    }
    if values.count > 5 {
      info.tm_sec = values[5]
    }
    let time: time_t = mktime(&info)
    self.init(timeIntervalSince1970: TimeInterval(time))
  }
}

extension URL: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) { self.init(fileURLWithPath: value) }
}

extension String {
  @inlinable public func leftpad(_ length: Int, character: Character = " ") -> String {
    var outString: String = self
    let extraLength = length - outString.count
    var i = 0
    while i < extraLength {
      outString.insert(character, at: outString.startIndex)
      i += 1
    }
    return outString
  }
  
  @inlinable public subscript(_ range: CountableRange<Int>) -> String {
    let start = self.index(self.startIndex, offsetBy: max(0, range.lowerBound))
    let end = self.index(start, offsetBy: min(self.count - range.lowerBound, range.upperBound - range.lowerBound))
    return String(self[start..<end])
  }

  @inlinable public subscript(_ range: CountablePartialRangeFrom<Int>) -> String {
    let start = self.index(self.startIndex, offsetBy: max(0, range.lowerBound))
    return String(self[start...])
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
  var a: Double = range.lowerBound
  var b: Double = range.upperBound
  for _ in 0..<maxIterations {
    let c: Double = (a + b) / 2.0
    let fc: Double = f(c)
    let fa: Double = f(a)
    if fc == goal || (b - a) / 2.0 < tolerance { return c }
    if (fc < goal && fa < goal) || (fc > goal && fa > goal) { a = c } else { b = c }
  }
  return Double.nan
}

@_alwaysEmitIntoClient public func concurrentSeek(
  goal: Double, _ range: ClosedRange<Double> = 0...1, tolerance: Double = 0.0001,
  maxIterations: Int = 100, _ f: (Double) -> Double
) -> Double {
  var x: [Double] = [range.lowerBound, 0.0, range.upperBound]
  var y: [Double] = [0.0, 0.0]
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

extension ClosedRange where Bound == Double {
  @inlinable public static func / (range: ClosedRange<Double>, _ count: Int) -> (interval: Double, iteration: [Double]) {
    let interval = (range.upperBound - range.lowerBound) / Double(count)
    let iteration = Array(stride(from: range.lowerBound, through: range.upperBound, by: interval))
    return (interval, iteration)
  }
}

extension Range where Bound == Double {
  @inlinable public static func / (range: Range<Double>, _ count: Int) -> (interval: Double, iteration: [Double]) {
    let interval = (range.upperBound - range.lowerBound) / Double(count)
    let iteration = Array(stride(from: range.lowerBound, to: range.upperBound, by: interval))
    return (interval, iteration)
  }
}

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
    if (a.sign == b.sign) { // Avoid overflowing to infinity, by choosing to
      return a + ((b - a) / 2)  // ? either advance by half the distance,
    } else {
      return (a + b) / 2  // : or use the sum divided by the count.
    }
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
