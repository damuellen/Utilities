//
//  Copyright 2017 Daniel Müllenborn
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//

import Libc
import Helpers

public struct Ratio: CustomStringConvertible, Codable {
  public var quotient: Double

  public var isZero: Bool { self == .zero }

  public static var zero: Ratio { Ratio(0) }

  public var percentage: Double { quotient * 100.0 }

  public var description: String {
    String(format: "%3.1f", percentage) + "%"
  }

  public init(percent: Double) {
    self.quotient = percent / 100
  }

  public init(_ value: Double) {
    precondition(0...1.01 ~= value, "Ratio out of range.")
    self.quotient = value > 1 ? 1 : value
  }

  public init(_ value: Double, cap: Double) {
    precondition(0 <= value, "Ratio out of range.")
    self.quotient = min(value, cap)
  }

  public mutating func limited(to max: Ratio) {
    quotient = min(max.quotient, quotient)
  }
}

extension Ratio: ExpressibleByFloatLiteral {
  public init(floatLiteral value: Double) {
    self.quotient = value
  }
}

extension Ratio: Equatable {
  public static func == (lhs: Ratio, rhs: Ratio) -> Bool {
    lhs.quotient == rhs.quotient
  }
}

extension Ratio: Comparable {
  public static func < (lhs: Ratio, rhs: Ratio) -> Bool {
    lhs.quotient < rhs.quotient
  }
}

extension Ratio {
  public var multiBar: String {
    let (bar_chunks, remainder) = Int(quotient * 80)
      .quotientAndRemainder(dividingBy: 8)
    let full = UnicodeScalar("█").value
    let fractionalPart =
      remainder > 0
      ? String(UnicodeScalar(full + UInt32(8 - remainder))!) : ""
    return String(repeating: "█", count: bar_chunks)
      + fractionalPart
      + String(repeating: " ", count: 10 - bar_chunks)
      + description
  }

  public var singleBar: String {
    let bar = Int(quotient * 7)
    let full = UnicodeScalar("█").value
    let block = String(UnicodeScalar(full - UInt32(7 - bar))!)
    return block + " " + description
  }
}

extension Polynomial {
  public func callAsFunction(_ ratio: Ratio) -> Double {
    evaluated(ratio.quotient)
  }
}
