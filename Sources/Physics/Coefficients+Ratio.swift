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

/// Represents a polynomial function, e.g. `2 + 3x + 4x²`.
public struct Polynomial: Codable, Equatable {
  /// Represents the coefficients of the polynomial
  public let coefficients: [Double]

  public init(coeffs: Double...) {
    self.coefficients = coeffs
  }

  public init(_ array: [Double]) {
    self.coefficients = array
  }

  public var indices: CountableRange<Int> { coefficients.indices }

  public var isEmpty: Bool { coefficients.isEmpty }

  public var isInapplicable: Bool { coefficients.count < 2 }

  @_transparent func evaluated(_ value: Double) -> Double {
    // Use Horner’s Method for solving
    coefficients.reversed().reduce(into: 0.0) { result, coefficient in
      result = coefficient.addingProduct(result, value)
    }
  }

  public func callAsFunction(_ temperature: Temperature) -> Double {
    evaluated(temperature.kelvin)
  }

  public func callAsFunction(_ value: Double) -> Double {
    evaluated(value)
  }

  public func callAsFunction(_ ratio: Ratio) -> Double {
    evaluated(ratio.quotient)
  }

  public subscript(index: Int) -> Double {
    coefficients[index]
  }
}

extension Polynomial: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: Double...) {
    self.coefficients = elements
  }
}

extension Polynomial: CustomStringConvertible {
  public var description: String {
    var s: String = ""
    for (i, c) in coefficients.enumerated() {
      s += "c\(i):" * String(format: "%.6e", c)
    }
    return s
  }
}

extension Polynomial {
  // https://github.com/OrbitalCalculations/hpnaff/blob/fdc8f01372b7632d8571b049a29d5b64c8fb1aee/Sources/hpNaff/Polynomial.swift#L98
  public static func fit<S: Collection>(x dependentValues: S, y independentValues: S, order: Int)-> Polynomial? where S.Element == Double {
    let dependentValues = Array(dependentValues)
    let independentValues = Array(independentValues)
    var B = [Double](repeating: 0.0, count: order + 1)
    var P = [Double](repeating: 0.0, count: ((order+1) * 2)+1)
    var A = [Double](repeating: 0.0, count: (order + 1)*2*(order + 1))
    var coefficients = [Double](repeating: 0.0, count: order + 1)

    // Verify initial conditions....
    // This method requires that the countOfElements >
    // (order+1)

    let countOfElements = dependentValues.count
    guard (countOfElements > order) else { return nil }

    // This method has imposed an arbitrary bound of
    // order <= maxOrder.  Increase maxOrder if necessary.
    let maxOrder = 6
    guard (order <= maxOrder) else { return nil }
    
    // Identify the column vector
    for ii in 0..<countOfElements {
      let x = dependentValues[ii]
      let y = independentValues[ii]
      var powx = 1.0

      for jj in 0..<(order + 1) {
        B[jj] = B[jj] + (y * powx)
        powx *= x
      }
    }
    // Initialize the PowX array
    P[0] = Double(countOfElements)

    // Compute the sum of the Powers of X
    for ii in 0..<countOfElements {
      let x    = dependentValues[ii]
      var powx = dependentValues[ii]

      for jj in 1 ..< ((2 * (order + 1)) + 1) {
            P[jj] = P[jj] + powx
            powx  *= x
        }
    }

    // Initialize the reduction matrix
    //
    for ii in 0..<(order + 1) {
      for jj in 0..<(order + 1) {
        A[(ii * (2 * (order + 1))) + jj] = P[ii+jj];
      }
      A[(ii*(2 * (order + 1))) + (ii + (order + 1))] = 1.0
    }

    // Move the Identity matrix portion of the redux matrix
    // to the left side (find the inverse of the left side
    // of the redux matrix
    for ii in 0..<(order + 1) {
      let x = A[(ii * (2 * (order + 1))) + ii]
      if (x != 0.0) {
        for kk in 0..<(2 * (order + 1)) {
          A[(ii * (2 * (order + 1))) + kk] =
                    A[(ii * (2 * (order + 1))) + kk] / x
        }
        for jj  in 0..<(order + 1) {
          if ((jj - ii) != 0) {
            let y = A[(jj * (2 * (order + 1))) + ii]
            for kk in 0..<(2 * (order + 1)) {
              A[(jj * (2 * (order + 1))) + kk] =
                  A[(jj * (2 * (order + 1))) + kk] -
                  y * A[(ii * (2 * (order + 1))) + kk]
            }
          }
        }
      } else {
        return nil
      }
    }

    // Calculate and Identify the coefficients
    for ii in 0..<(order + 1) {
      var x = 0.0
      for kk in 0..<(order + 1) {
        x += (A[(ii * (2 * (order + 1))) + (kk + (order + 1))] * B[kk])
      }
      coefficients[ii] = x
    }
    return self.init(coefficients)
  }
}

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
    let fractionalPart = remainder > 0
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
