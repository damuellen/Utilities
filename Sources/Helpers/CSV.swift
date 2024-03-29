//
//  Copyright 2023 Daniel Müllenborn
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

/// A struct to read CSV files containing floating-point numbers.
/// - Note: Auto-detect of optional String headers.
public struct CSVReader {
  /// Optional String array representing the header row of the CSV file.
  public let headerRow: [String]?
  /// Array of arrays containing the data rows of the CSV file as Double values.
  public let dataRows: [[Double]]
  /// Optional integer representing the index of the date column.
  private let dateColumn: Int?
  /// CSV representation of the entire data.
  public var csv: String { peek(dataRows.indices) }
  /// CSV representation of the first 30 rows.
  public var head: String { peek(0..<min(30, dataRows.endIndex)) }
  /// CSV representation of the last 30 rows (or all rows if less than 30).
  public var tail: String {
    if dataRows.count > 30 {
      return peek(dataRows.endIndex - 30..<dataRows.endIndex)
    }
    return peek(0..<dataRows.endIndex)
  }
  /// Array of Date objects parsed from the date column, if available.
  public var dates: [Date] {
    if let dateColumn = dateColumn {
      return dataRows.indices.map { Date(timeIntervalSince1970: dataRows[$0][dateColumn]) }
    } else {
      return []
    }    
  }
  /// Generate a CSV representation of the specified rows range.
  public func peek(_ range: Array<Any>.Indices) -> String {
    if let headerRow = headerRow {
      let minWidth: Int = headerRow.map { $0.count }.max() ?? 1
      let formatted = Array.tabulated(dataRows[range], minWidth: minWidth)
      let width = (terminalWidth() / formatted.1 + 1) * formatted.1 + 1
      return String(
        headerRow.map { $0.leftpad(formatted.1) }
          .joined(separator: " ").prefix(width)) + "\n" + formatted.0
    }
    return Array.tabulated(dataRows[range]).0
  }
  /// Access data rows using subscript.
  public subscript(row: Int) -> [Double] {
    dataRows[row]
  }
  /// Access a specific value using subscript with column name and row index.
  public subscript(column: String, row: Int) -> Double {
    dataRows[row][headerRow?.firstIndex(of: column) ?? dataRows[row].startIndex]
  }
  /// Access data for a specific column using subscript with column name.
  public subscript(column: String) -> [Double] {
    let c = headerRow?.firstIndex(of: column) ?? dataRows[0].startIndex
    return self[column: c]
  }
  /// Access data for a specific column using subscript with column index.
  public subscript(column c: Int) -> [Double] {
    return [Double](unsafeUninitializedCapacity: dataRows.count) {
      uninitializedMemory, resultCount in
      resultCount = dataRows.count
      for i in dataRows.indices {
        uninitializedMemory[i] = dataRows[i][c]
      }
    }
  }
  /// Initialize a CSVReader from a file path.
  @available(macOS 10.15.4, iOS 14, watchOS 7, tvOS 14, *)
  public init?(atPath: String, separator: Unicode.Scalar = ",", filter: String..., skip: String..., dateColumn: Int? = nil) {
    let fileHandle = FileHandle(forReadingAtPath: atPath)
    let data = try? fileHandle?.readToEnd()
    try? fileHandle?.close()
    if let data = data { 
      self.init(data: data, separator: separator, filter: filter, skip: skip, dateColumn: dateColumn)
    } else {
      return nil
    }
  }
  /// Initialize a CSVReader from raw data.
  public init?(data: Data, separator: Unicode.Scalar = ",", filter: [String] = [], skip: [String] = [], dateColumn: Int? = nil) {
    let newLine = UInt8(ascii: "\n")
    let cr = UInt8(ascii: "\r")
    let separator = UInt8(ascii: separator)
    let isLetter = { $0 > UInt8(ascii: "@") }
    guard let firstNewLine = data.firstIndex(of: newLine) else { return nil }
    let firstSeparator = data.firstIndex(of: separator) ?? 0
    guard firstSeparator < firstNewLine else { return nil }
    let hasCR = data[data.index(before: firstNewLine)] == cr
    let end = hasCR ? data.index(before: firstNewLine) : firstNewLine
    let hasHeader = data[..<end].contains(where: isLetter)
    let start = hasHeader ? data.index(after: firstNewLine) : data.startIndex
    var excluded: [Int]
    if hasHeader {
      let headers = data[..<end].split(separator: separator).map { slice in
        String(decoding: slice, as: UTF8.self)
      }
      var unique = [String]()
      for (n, header) in headers.enumerated() {
        if unique.contains(header) {
          unique.append(header + String(n))
        } else {
          unique.append(header)
        }
      }
      excluded = headers.indices.filter { i in        
        skip.reduce(false) { headers[i].elementsEqual($1) } ||
        filter.reduce(false) { !headers[i].contains($1) }
      }
      excluded.reversed().forEach({ if $0 != dateColumn { unique.remove(at: $0) } })
      self.headerRow = unique      
    } else {
      excluded = skip.compactMap { Int($0) }
      self.headerRow = nil
    }
    self.dateColumn = dateColumn
    if let dateColumn = dateColumn {
      excluded.append(dateColumn)
      self.dataRows = data[start...].withUnsafeBytes { content in
        let lines = content.split(separator: newLine)
        return lines.map { line in
          let line = hasCR ? line.dropLast() : line
          let buffer = UnsafeRawBufferPointer(rebasing: line)
          let date = parseDate(buffer, separator: separator, at: dateColumn)
          let row = parse(buffer, separator: separator, exclude: excluded)
          return [date] + row
        }
      }      
    } else {
      self.dataRows = data[start...].withUnsafeBytes { content in
        let lines = content.split(separator: newLine)
        return lines.map { line in
          let line = hasCR ? line.dropLast() : line
          let buffer = UnsafeRawBufferPointer(rebasing: line)
          return parse(buffer, separator: separator, exclude: excluded)
        }
      }
    }
  }  
}

/// Function to parse numerical data from a buffer with a specific separator.
private func parse(_ buffer: UnsafeRawBufferPointer, separator: UInt8, exclude: [Int]) -> [Double] {
  let power = [1.0, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12, 1e13, 1e14, 1e15, 1e16, 1e17]
  let base = buffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
  var a = [Double]()
  var p: UnsafePointer<UInt8> = base
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
      } else if p.pointee == UInt8(ascii: "+") {
        p = p.successor()
      }
      while p.pointee >= UInt8(ascii: "0") && p.pointee <= UInt8(ascii: "9") {
        e = Int(p.pointee - UInt8(ascii: "0")) + e * 10
        p = p.successor()
      }
      e = min(e, 16)
      if neg { r = r / power[e] } else { r = r * power[e] }
    }
    if p == base.advanced(by: d) { a.append(.nan) }
    else { if neg { a.append(-r) } else { a.append(r) } }
  }
  return a
}

/// Function to parse the date from a buffer with a specific separator and at a specific index.
private func parseDate(_ buffer: UnsafeRawBufferPointer, separator: UInt8, at: Int) -> Double {
  let dateString = buffer.split(separator: separator, maxSplits: at + 1, omittingEmptySubsequences: false)[at]
  let date = dateString.split(maxSplits: 6, omittingEmptySubsequences: false, whereSeparator: { $0 < UInt8(ascii: "0") || $0 > UInt8(ascii: "9")})
  let values = date.prefix(6).map { c -> Int32 in
    c.map { Int32($0) - 48 }.reduce(into: 0, { $0 = $0 * 10 + $1 })
  }
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
  return Double(mktime(&info))
}
