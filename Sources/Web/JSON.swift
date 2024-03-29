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

extension JSONDecoder {
  public static let shared = JSONDecoder()
}

extension JSONEncoder {
  public static let shared: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }()
}

extension Decodable {
  public static func decodeFromJSON(data: Data) throws -> Self {
    return try JSONDecoder.shared.decode(Self.self, from: data)
  }
  @available(macOS 10.15.4, iOS 13.4, watchOS 6, tvOS 13, *)
  public static func loadFromJSON(file: URL) throws -> Self {
    let fileHandle = try FileHandle(forReadingFrom: file)
    if let data = try fileHandle.readToEnd() {
      try fileHandle.close()
      return try decodeFromJSON(data: data)
    } else {
      fatalError()
    }
  }
  #if !canImport(WASILibc)
  @available(macOS 10.15.4, iOS 13.4, watchOS 6, tvOS 13, *)
  public static func loadFromJSONIfExists(file: URL) throws -> Self? {
    guard FileManager.default.fileExists(atPath: file.path) else { return nil }
    return try loadFromJSON(file: file)
  }
  #endif
}

extension Encodable {
  public func encodeToJSON() throws -> String {
    let data = try JSONEncoder.shared.encode(self)
    return String(decoding: data, as: Unicode.UTF8.self)
  }
  #if !canImport(WASILibc)
  public func storeToJSON(file: URL) throws {
    let data = try JSONEncoder.shared.encode(self)
    let dir = file.deletingLastPathComponent()
    try FileManager.default.createDirectory(
      at: dir, withIntermediateDirectories: true
    )
    try data.write(to: file, options: [.atomic])
  }
  #endif
}
