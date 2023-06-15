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

/// Represents a polynomial function, e.g. `2 + 3x + 4x²`.
public struct Polynomial: Codable, Equatable {
  /// Represents the coefficients of the polynomial
  public let coefficients: [Double]

  public init(coeffs: Double...) { self.coefficients = coeffs }

  public init(_ array: [Double]) { self.coefficients = array }

  public var indices: CountableRange<Int> { coefficients.indices }

  public var isEmpty: Bool { coefficients.isEmpty }

  public var isInapplicable: Bool { coefficients.count < 2 }

  @inlinable public func evaluated(_ value: Double) -> Double {
    // Use Horner’s Method for solving
    coefficients.reversed().reduce(into: 0.0) { result, coefficient in
      result = coefficient.addingProduct(result, value)
    }
  }

  public func callAsFunction(_ value: Double) -> Double {
    evaluated(value)
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
      s += "c\(i):" * String(format: "%.15g", c)
    }
    return s
  }
}

extension Polynomial {
  // https://github.com/OrbitalCalculations/hpnaff/blob/fdc8f01372b7632d8571b049a29d5b64c8fb1aee/Sources/hpNaff/Polynomial.swift#L98
  public static func fit<S: Collection>(
    x dependentValues: S, y independentValues: S, order: Int = 4
  ) -> Polynomial? where S.Element == Double {
    let dependentValues = Array(dependentValues)
    let independentValues = Array(independentValues)
    var B = [Double](repeating: 0.0, count: order + 1)
    var P = [Double](repeating: 0.0, count: ((order + 1) * 2) + 1)
    var A = [Double](repeating: 0.0, count: (order + 1) * 2 * (order + 1))
    var coefficients = [Double](repeating: 0.0, count: order + 1)

    // Verify initial conditions....
    // This method requires that the countOfElements >
    // (order+1)

    let countOfElements = dependentValues.count
    guard countOfElements > order else { return nil }

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
      let x = dependentValues[ii]
      var powx = dependentValues[ii]

      for jj in 1..<((2 * (order + 1)) + 1) {
        P[jj] = P[jj] + powx
        powx *= x
      }
    }

    // Initialize the reduction matrix
    //
    for ii in 0..<(order + 1) {
      for jj in 0..<(order + 1) {
        A[(ii * (2 * (order + 1))) + jj] = P[ii + jj]
      }
      A[(ii * (2 * (order + 1))) + (ii + (order + 1))] = 1.0
    }

    // Move the Identity matrix portion of the redux matrix
    // to the left side (find the inverse of the left side
    // of the redux matrix
    for ii in 0..<(order + 1) {
      let x = A[(ii * (2 * (order + 1))) + ii]
      if x != 0.0 {
        for kk in 0..<(2 * (order + 1)) {
          A[(ii * (2 * (order + 1))) + kk] =
            A[(ii * (2 * (order + 1))) + kk] / x
        }
        for jj in 0..<(order + 1) {
          if (jj - ii) != 0 {
            let y = A[(jj * (2 * (order + 1))) + ii]
            for kk in 0..<(2 * (order + 1)) {
              A[(jj * (2 * (order + 1))) + kk] =
                A[(jj * (2 * (order + 1))) + kk] - y * A[(ii * (2 * (order + 1))) + kk]
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
