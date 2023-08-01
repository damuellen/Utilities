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

/// Represents a polynomial function, e.g. `2 + 3x + 4x²`.
public struct Polynomial: Codable, Equatable {
  /// Represents the coefficients of the polynomial.
  public let coefficients: [Double]

  /// Initializes a polynomial with the given coefficients.
  public init(coeffs: Double...) { self.coefficients = coeffs }

  /// Initializes a polynomial with the given array of coefficients.
  public init(_ array: [Double]) { self.coefficients = array }

  /// A range of indices for the coefficients.
  public var indices: CountableRange<Int> { coefficients.indices }

  /// Checks if the polynomial is empty (no coefficients).
  public var isEmpty: Bool { coefficients.isEmpty }

  /// Checks if the polynomial has at least two coefficients, making it applicable.
  public var isInapplicable: Bool { coefficients.count < 2 }

  /// Evaluates the polynomial at a given value using Horner’s Method.
  @inlinable public func evaluated(_ value: Double) -> Double {
    coefficients.reversed().reduce(into: 0.0) { result, coefficient in
      result = coefficient.addingProduct(result, value)
    }
  }

  /// Allows calling the polynomial as a function for evaluation.
  public func callAsFunction(_ value: Double) -> Double { evaluated(value) }

  /// Accesses the coefficient at the specified index.
  public subscript(index: Int) -> Double { coefficients[index] }
}

extension Polynomial: ExpressibleByArrayLiteral {
  /// Initializes a polynomial with an array literal.
  public init(arrayLiteral elements: Double...) {
    self.coefficients = elements
  }
}

extension Polynomial: CustomStringConvertible {
  /// A string representation of the polynomial, showing the coefficients.
  public var description: String {
    coefficients.enumerated().reduce(into: "") {
      $0 += "c\($1.offset):" * String(format: "%.15g", $1.element)
    }
  }
}

extension Polynomial {
  /// Fits a polynomial to a set of data points using least squares polynomial regression.
  ///
  /// - Parameters:
  ///   - x: The collection of dependent values (x-coordinates) for the data points.
  ///   - y: The collection of independent values (y-coordinates) for the data points.
  ///   - order: The degree of the polynomial to fit (default is 4).
  /// - Returns: A polynomial that approximates the data points or nil if fitting fails.
  public static func fit<S: Collection>(
    x dependentValues: S, y independentValues: S, order: Int = 4
  ) -> Polynomial? where S.Element == Double {
    let dependentValues = Array(dependentValues)
    let independentValues = Array(independentValues)

    // Check if the number of data points is sufficient to perform polynomial regression.
    let countOfElements = dependentValues.count
    guard countOfElements > order else {
      return nil // Not enough data points for the desired polynomial order.
    }

    // Initialize arrays to hold intermediate calculations.
    var B = [Double](repeating: 0.0, count: order + 1)
    var P = [Double](repeating: 0.0, count: ((order + 1) * 2) + 1)
    var A = [Double](repeating: 0.0, count: (order + 1) * 2 * (order + 1))
    var coefficients = [Double](repeating: 0.0, count: order + 1)

    // Initialize the PowX array (holds the count of elements).
    P[0] = Double(countOfElements)
    
    // Calculate the sums of powers of x and y.
    for ii in 0..<countOfElements {
      let x = dependentValues[ii]
      let y = independentValues[ii]
      var powx = 1.0

      // Calculate the sum of powers of x for each term in the polynomial.
      for jj in 0..<(order + 1) {
        B[jj] = B[jj] + (y * powx)
        powx *= x
      }

      // Calculate the sum of powers of x for finding the inverse of the left side of the redux matrix.
      powx = x
      for jj in 1..<((2 * (order + 1)) + 1) {
        P[jj] = P[jj] + powx
        powx *= x
      }
    }

    // Construct the left side of the redux matrix.
    for ii in 0..<(order + 1) {
      for jj in 0..<(order + 1) {
        A[(ii * (2 * (order + 1))) + jj] = P[ii + jj]
      }
      A[(ii * (2 * (order + 1))) + (ii + (order + 1))] = 1.0
    }

    // Move the Identity matrix portion of the redux matrix to the left side
    // (find the inverse of the left side of the redux matrix).
    for ii in 0..<(order + 1) {
      let x = A[(ii * (2 * (order + 1))) + ii]
      if x != 0.0 {
        for kk in 0..<(2 * (order + 1)) {
          A[(ii * (2 * (order + 1))) + kk] = A[(ii * (2 * (order + 1))) + kk] / x
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
        return nil // The left side of the redux matrix is singular, fitting failed.
      }
    }

    // Calculate and identify the coefficients of the polynomial.
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
