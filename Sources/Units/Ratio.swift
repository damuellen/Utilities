//
//  Copyright 2023 Daniel Müllenborn
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//

import Libc
import Helpers

/// A struct representing a ratio value between 0 and 1.
public struct Ratio: CustomStringConvertible, Codable {
  /// The quotient value of the ratio.
  public var quotient: Double

  /// Check if the ratio is zero.
  public var isZero: Bool { self == .zero }

  /// Zero ratio value.
  public static var zero: Ratio { Ratio(0) }

  /// The ratio value represented as a percentage.
  public var percentage: Double { quotient * 100.0 }

  /// A textual representation of the ratio value as a percentage.
  public var description: String {
    String(format: "%3.1f", percentage) + "%"
  }

  /// Create a ratio instance from a percentage value.
  /// - Parameter percent: The percentage value.
  public init(percent: Double) {
    quotient = percent / 100
  }

  /// Create a ratio instance with a given value.
  /// - Parameter value: The value for the ratio.
  public init(_ value: Double) {
    precondition(0...1.01 ~= value, "Ratio out of range.")
    quotient = value > 1 ? 1 : value
  }

  /// Create a ratio instance with a given value and cap.
  /// - Parameters:
  ///   - value: The value for the ratio.
  ///   - cap: The maximum value the ratio can have.
  public init(_ value: Double, cap: Double) {
    precondition(0 <= value, "Ratio out of range.")
    quotient = min(value, cap)
  }

  /// Limit the ratio to a maximum value.
  /// - Parameter max: The maximum ratio value.
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
  /// Get a multi-bar representation of the ratio value.
  /// The multi-bar is represented by █ characters and spaces to form a bar of length 10.
  /// - Returns: The multi-bar representation.
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

  /// Get a single-bar representation of the ratio value.
  /// The single-bar is represented by a partial █ character followed by a space.
  /// - Returns: The single-bar representation.
  public var singleBar: String {
    let bar = Int(quotient * 7)
    let full = UnicodeScalar("█").value
    let block = String(UnicodeScalar(full - UInt32(7 - bar))!)
    return block + " " + description
  }
}

/// An extension of Polynomial to allow calling it as a function with a Ratio argument.
extension Polynomial {
  /// Evaluate the polynomial at a given ratio value.
  /// - Parameter ratio: The ratio value to be used as input for the polynomial evaluation.
  /// - Returns: The result of the polynomial evaluation at the given ratio value.
  public func callAsFunction(_ ratio: Ratio) -> Double {
    evaluated(ratio.quotient)
  }
}
