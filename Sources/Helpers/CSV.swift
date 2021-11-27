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
/// - Important: Scientific notation is not supported.
public struct CSV {
  public let headerRow: [String]?
  public let dataRows: [[Double]]

  public var csv: String { peek(dataRows.indices) }

  public var head: String { peek(0..<30) }

  public var tail: String { 
    if dataRows.count > 30 {
      return peek(dataRows.endIndex-30..<dataRows.endIndex) 
    }
    return peek(0..<dataRows.endIndex) 
  }

  public func peek(_ range: Array.Indices) -> String {
    if let headerRow = headerRow {
      return headerRow.joined(separator: ", ") + "\n" 
       + Array.formatted(dataRows[range])
    }
    return Array.formatted(dataRows[range])
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
    return Array<Double>(unsafeUninitializedCapacity: dataRows.count) {
      uninitializedMemory, resultCount in
      resultCount = dataRows.count
      for i in dataRows.indices {
        uninitializedMemory[i] = dataRows[i][c]
      }
    }
  }

  public init?(path: String, separator: Unicode.Scalar = ",") {
    let url = URL(fileURLWithPath: path)
    guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe, .uncached])
    else { return nil }
    self.init(data: data, separator: separator)
  }

  public init?(data: Data, separator: Unicode.Scalar = ",") {
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
    self.headerRow = !hasHeader ? nil : data[..<end].split(separator: separator).map { slice in
      String(decoding: slice.filter(isSpace), as: UTF8.self)
    }
    #if DEBUG
    if let headerRow = headerRow {
      print("Header row detected.", headerRow)
    } else {
      print("No header.")
    }
    #endif
    self.dataRows = data[start...].withUnsafeBytes { content in
      content.split(separator: newLine).concurrentMap(minBatchSize: 1000) { line in
        let line = hasCR ? line.dropLast() : line
        let buffer = UnsafeRawBufferPointer(rebasing: line)
        return parse(buffer, separator: separator)
      }
    }
    #if DEBUG
    if let headerRow = headerRow, dataRows[0].count != headerRow.count {
      print("Header missing !")
      print(dataRows[0])
    }
    #endif
  }
}

public extension Array where Element == Double {
  var formatted: String {
    self.map(\.description).joined(separator: ", ")
  }
}

public extension Array where Element == Double {
  static func formatted(_ array: ArraySlice<[Double]>) -> String {
    array.map(\.formatted).joined(separator: "\n")
  }
}

private func parse(_ p: UnsafeRawBufferPointer, separator: UInt8) -> [Double] {
  var p = p.baseAddress!.assumingMemoryBound(to: UInt8.self)
  var r = [Double.zero]
  var neg = false
  var i = 0
  while true {
    while p.pointee == UInt8(ascii: " ") { p = p.successor() }
    if p.pointee == UInt8(ascii: "-") {
      neg = true
      p = p.successor()
    }
    while p.pointee >= UInt8(ascii: "0") && p.pointee <= UInt8(ascii: "9") {
      r[i] = Double(p.pointee - UInt8(ascii: "0")).addingProduct(r[i], 10)
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
      for _ in 0..<n { f /= 10 }
      r[i] += f
    }
    if neg { r[i] = -r[i] }
    while p.pointee == UInt8(ascii: " ") { p = p.successor() }
    if p.pointee == separator {
      p = p.successor()
      r.append(Double.zero)
      i += 1
    } else {
      break
    }
  }
  return r
}

