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

/// Read files only containing floating-point numbers.
/// - Note: Auto-detect of optional String headers.
public struct CSVReader {
  public let headerRow: [String]?
  public let dataRows: [[Double]]

  public var csv: String { peek(dataRows.indices) }

  public var head: String { peek(0..<min(30, dataRows.endIndex)) }

  public var tail: String {
    if dataRows.count > 30 {
      return peek(dataRows.endIndex - 30..<dataRows.endIndex)
    }
    return peek(0..<dataRows.endIndex)
  }

  public func peek(_ range: Array<Any>.Indices) -> String {
    if let headerRow = headerRow {
      let minWidth = headerRow.map { $0.count }.max() ?? 1
      let formatted = Array.justified(dataRows[range], minWidth: minWidth)
      let width = (terminalWidth() / formatted.1 + 1) * formatted.1 + 1
      return String(
        headerRow.map { $0.leftpad(length: formatted.1) }
          .joined(separator: " ").prefix(width)) + "\n" + formatted.0
    }
    return Array.justified(dataRows[range]).0
  }

  public subscript(row: Int) -> [Double] {
    dataRows[row]
  }

  public subscript(column: String, row: Int) -> Double {
    dataRows[row][headerRow?.firstIndex(of: column) ?? dataRows[row].startIndex]
  }

  public subscript(column: String) -> [Double] {
    let c = headerRow?.firstIndex(of: column) ?? dataRows[0].startIndex
    return self[column: c]
  }

  public subscript(column c: Int) -> [Double] {
    return [Double](unsafeUninitializedCapacity: dataRows.count) {
      uninitializedMemory, resultCount in
      resultCount = dataRows.count
      for i in dataRows.indices {
        uninitializedMemory[i] = dataRows[i][c]
      }
    }
  }

  public init?(atPath: String, separator: Unicode.Scalar = ",", skip: String...) {
    let url = URL(fileURLWithPath: atPath)
    guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe, .uncached])
    else { return nil }
    self.init(data: data, separator: separator, skip: skip)
  }

  public init?(data: Data, separator: Unicode.Scalar = ",", skip: [String] = []) {
    let newLine = UInt8(ascii: "\n")
    let cr = UInt8(ascii: "\r")
    let separator = UInt8(ascii: separator)
    let isSpace = { $0 != UInt8(ascii: " ") }
    let isLetter = { $0 > UInt8(ascii: "@") }
    guard let firstNewLine = data.firstIndex(of: newLine) else { return nil }
    let firstSeparator = data.firstIndex(of: separator) ?? 0
    guard firstSeparator < firstNewLine else { return nil }
    let hasCR = data[data.index(before: firstNewLine)] == cr
    let end = hasCR ? data.index(before: firstNewLine) : firstNewLine
    let hasHeader = data[..<end].contains(where: isLetter)
    let start = hasHeader ? data.index(after: firstNewLine) : data.startIndex
    var headers = !hasHeader
      ? nil
      : data[..<end].split(separator: separator).map { slice in
        String(decoding: slice.filter(isSpace), as: UTF8.self)
      }
    let excluded: [Int]
    if headers != nil {
      excluded = skip.compactMap { headers!.firstIndex(of: $0) }
      excluded.reversed().forEach { headers!.remove(at: $0) }
    } else {
      excluded = skip.compactMap { Int($0) }
    }
    self.headerRow = headers
    self.dataRows = data[start...].withUnsafeBytes { content in
      content.split(separator: newLine).map { line in
        let line = hasCR ? line.dropLast() : line
        let buffer = UnsafeRawBufferPointer(rebasing: line)
        return parse(buffer, separator: separator, exclude: excluded)
      }
    }
  }
}

extension Array where Element == Double {
  public var formatted: String {
    self.map { $0.description }.joined(separator: ", ")
  }
}

extension Array where Element == Double {
  public static func justified(_ array: ArraySlice<[Double]>, minWidth: Int = 1) -> (String, Int) {
    let m = Int(array.map { $0.largest }.reduce(Double(minWidth), { Swift.max($0, $1) }))
      .description.count
    let width = (terminalWidth() / minWidth + 1) * minWidth + 1
    return (
      array.map { row in
        String(
          row.map { String(format: "%.1f", $0).leftpad(length: m + 2) }.joined(separator: " ")
            .prefix(width))
      }.joined(separator: "\n"), m + 2
    )
  }
}

extension Array where Element == Double {
  var largest: Double { self.map { $0.magnitude }.max() ?? 0 }
}

private func parse(_ buffer: UnsafeRawBufferPointer, separator: UInt8, exclude: [Int]) -> [Double] {
  let power = [1.0, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12, 1e13, 1e14, 1e15, 1e16, 1e17]
  let base = buffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
  var a = [Double]()
  var p = base
  var distance = [0]
  for (n, p) in buffer.enumerated() { if p == separator { distance.append(n+1) } }
  for (n, d) in distance.enumerated() {
    if exclude.contains(n) { continue }
    p = base.advanced(by: d)
    var r = Double.zero
    var neg = false
    while p.pointee == UInt8(ascii: " ") { p = p.successor() }
    if p.pointee == UInt8(ascii: "-") {
      neg = true
      p = p.successor()
    }
    while p.pointee >= UInt8(ascii: "0") && p.pointee <= UInt8(ascii: "9") {
      r = Double(p.pointee - UInt8(ascii: "0")).addingProduct(r, 10)
      p = p.successor()
    }
    if p.pointee == UInt8(ascii: ".") {
      var f = Double.zero
      var n = 0
      p = p.successor()
      while p.pointee >= UInt8(ascii: "0") && p.pointee <= UInt8(ascii: "9") {
        f = Double(p.pointee - UInt8(ascii: "0")).addingProduct(f, 10)
        p = p.successor()
        n += 1
      }
      r += f / power[n]  // Here be dragons.
    }
    if p.pointee == UInt8(ascii: "E") || p.pointee == UInt8(ascii: "e") {
      var e = Int.zero
      var neg = false
      p = p.successor()
      if p.pointee == UInt8(ascii: "-") {
        neg = true
        p = p.successor()
      }
      while p.pointee >= UInt8(ascii: "0") && p.pointee <= UInt8(ascii: "9") {
        e = Int(p.pointee - UInt8(ascii: "0")) + e * 10
        p = p.successor()
      }
      e = min(e, 16)
      if neg { r = r / power[e] } else { r = r * power[e] }
    }
    if neg { a.append(-r) } else { a.append(r) }
  }
  return a
}
