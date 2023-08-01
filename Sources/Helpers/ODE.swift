//
//  Copyright 2023 Daniel Müllenborn
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//

#if canImport(Numerics)
  import Numerics
#else
  import Libc
#endif
/// Performs explicit Runge-Kutta integration for solving ordinary differential equations (ODEs).
///
/// - Parameters:
///   - tableau: A ButchersTableau representing the Runge-Kutta tableau with coefficients.
///   - ys: An inout buffer to store the computed solution vectors at different time points.
///   - ts: An array of time points at which to compute the solution.
///   - y0: The initial value vector (initial condition) for the ODE.
///   - dydx: A function that takes the current value vector and time, and returns the time derivative vector.
///   - tol: The tolerance value used for controlling the step size in the integration.
/// - Returns: The number of computed solution vectors stored in `ys`.
func explicitRungeKutta<Vector: OdeVector, Tableau: ButchersTableau>(
  tableau: Tableau, ys: inout UnsafeMutableBufferPointer<Vector>, ts: [Vector.Scalar],
  y0: Vector, dydx: (Vector, Vector.Scalar) -> Vector, tol: Vector.Scalar
) -> Int
where Vector.Scalar == Tableau.Scalar {
  // Extracting parameters from the provided ButchersTableau.
  let stages = tableau.stages // Number of stages in the Runge-Kutta method.
  let dense_order = tableau.dense_order // The order for dense output (higher order than the method).
  let order = tableau.order // The order of accuracy of the method.
  let a = tableau.a // The matrix of coefficients for computing intermediate values.
  let p = tableau.p // The matrix of coefficients for dense output computation.
  let c = tableau.c // The nodes (time points) for the stages in the method.
  let b = tableau.b // The coefficients for computing the solution.
  let b_hat = tableau.b_hat // The coefficients for estimating the solution.

  // Variables for storing intermediate values during integration.
  var y_hat_n = y0 // Intermediate value vector at current step.
  ys[0] = y0 // Storing the initial value vector in the result buffer.
  var it = 1 // Index for storing the solution vectors in the result buffer.
  var k: [Vector] = [Vector](repeating: Vector(repeating: 0), count: stages) // Array for stage derivatives.

  // Extracting time information from the provided array.
  let N = ts.count
  if N == 0 { return 0 } // If no time points provided, return 0 (no solutions computed).
  var t_n = ts[0] // Current time point.
  var h_n = ts[N - 1] - t_n // Initial step size based on the last time point.
  var step_count = 0 // Count of successful integration steps.

  // Computing the derivative at the initial value.
  k[stages - 1] = dydx(y0, t_n)

  // Main integration loop: iterates until the last time point is reached.
  while t_n < ts[N - 1] {
    var step_rejected = true // Flag to check if the current step should be rejected.

    // Step size adaptation loop: iterates until a step size is accepted.
    while step_rejected {
      let last_k_store = k[stages - 1] // Store the last stage derivative to restore it if the step is rejected.
      k[0] = k[stages - 1] // Start with the last stage derivative for the first stage.

      // Compute derivatives at intermediate stages using the Runge-Kutta method.
      for i in 1..<stages {
        var sum_ak = Vector(repeating: 0)
        for j in 0..<i { sum_ak += a[i][j] * k[j] } // Compute the weighted sum of previous derivatives.
        k[i] = dydx(y_hat_n + h_n * sum_ak, t_n + c[i] * h_n) // Compute the derivative at the current stage.
      }

      // Compute the error estimate and the next step solution using dense output.
      var error = Vector(repeating: 0) // Error estimate vector.
      var sum_bk = Vector(repeating: 0) // Sum of weighted derivatives for dense output.
      for i in 0..<stages {
        sum_bk += b_hat[i] * k[i] // Compute the weighted sum of stage derivatives for dense output.
        error += (b_hat[i] - b[i]) * k[i] // Compute the error estimate vector.
      }
      let y_hat_np1 = y_hat_n + h_n * sum_bk // Compute the solution estimate at the next step.

      let E_hp1 = (h_n * error).inf_norm() // Compute the infinity norm of the error estimate.
      // Check if the error is within tolerance, and if yes, store the solution vector at the next time point.
      if E_hp1 < tol {
        let t_np1 = t_n + h_n // Compute the time at the next step.
        // Store the solution vectors at intermediate time points based on dense output coefficients.
        while it < ts.count && t_np1 >= ts[it] {
          let sigma = (ts[it] - t_n) / h_n // Compute the normalized time value for dense output.
          var Phi = Vector(repeating: 0)
          for i in 0..<stages {
            // Compute the dense output approximation based on the coefficients p.
            var term = sigma
            var b_i = term * p[i][0]
            for j in 1..<dense_order {
              term *= sigma
              b_i += term * p[i][j]
            }
            Phi += b_i * k[i] // Add the dense output term to the solution vector.
          }
          ys[it] = y_hat_n + h_n * Phi // Store the solution vector at the next time point.
          it += 1 // Increment the index for the next time point.
        }
        step_rejected = false // Mark the step as accepted.
        y_hat_n = y_hat_np1 // Update the intermediate value vector for the next step.
        t_n = t_np1 // Update the current time point.
        step_count += 1 // Increment the step count.
      } else {
        k[stages - 1] = last_k_store // Restore the last stage derivative if the step is rejected.
      }

      // Adjust the step size for the next iteration using step size control based on the error.
      // The step size is reduced to achieve a more accurate solution.
      #if canImport(Numerics)
      h_n *= 0.9 * Scalar.pow(tol / E_hp1, 1.0 / (Scalar(order) + 1.0))
      #else
      h_n *= Vector.Scalar(0.9 * pow(Double(tol) / Double(E_hp1), 1.0 / (Double(order) + 1.0)))
      #endif
    }
  }
  return it // Return the number of computed solution vectors.
}
/// ButchersTableau represents a set of coefficients for the explicit Runge-Kutta method.
/// The table consists of matrices and vectors used to calculate the solution and error estimates.
protocol ButchersTableau {
  associatedtype Scalar
  /// Number of stages in the Runge-Kutta method.
  var stages: Int { get }
  /// The order of accuracy of the method.
  var order: Int { get }
  /// The order of the error estimator.
  var estimator_order: Int { get }
  /// The order for dense output (higher order than the method).
  var dense_order: Int { get }
  /// The nodes (time points) for the stages in the method.
  var c: [Scalar] { get }
  /// The matrix of coefficients for computing intermediate values.
  var a: [[Scalar]] { get }
  /// The coefficients for estimating the solution.
  var b_hat: [Scalar] { get }
  /// The coefficients for computing the solution.
  var b: [Scalar] { get }
  /// The matrix of coefficients for dense output computation.
  var p: [[Scalar]] { get }
}
/// Coefficients for the Dormond-Price ButchersTableau
struct DormondPrice<Scalar: BinaryFloatingPoint>: ButchersTableau {
  typealias Scalar = Scalar
  let stages = 7
  let order = 5
  let estimator_order = 4
  let dense_order = 5
  let c: [Scalar] = [
    Scalar(0.0), Scalar(1.0 / 5.0), Scalar(3.0 / 10.0), Scalar(4.0 / 5.0), Scalar(8.0 / 9.0),
    Scalar(1.0), Scalar(1.0),
  ]
  let a: [[Scalar]] = [
    [Scalar(0.0), Scalar(0.0), Scalar(0.0), Scalar(0.0), Scalar(0.0)],
    [Scalar(1.0 / 5.0), Scalar(0.0), Scalar(0.0), Scalar(0.0), Scalar(0.0)],
    [Scalar(3.0 / 40.0), Scalar(9.0 / 40.0), Scalar(0.0), Scalar(0.0), Scalar(0.0)],
    [Scalar(44.0 / 45.0), Scalar(-56.0 / 15.0), Scalar(32.0 / 9.0), Scalar(0.0), Scalar(0.0)],
    [
      Scalar(19372.0 / 6561.0), Scalar(-25360.0 / 2187.0), Scalar(64448.0 / 6561.0),
      Scalar(-212.0 / 729.0), Scalar(0.0),
    ],
    [
      Scalar(9017.0 / 3168.0), Scalar(-355.0 / 33.0), Scalar(46732.0 / 5247.0),
      Scalar(49.0 / 176.0), Scalar(-5103.0 / 18656.0),
    ],
    [
      Scalar(35.0 / 384.0), Scalar(0.0), Scalar(500.0 / 1113.0), Scalar(125.0 / 192.0),
      Scalar(-2187.0 / 6784.0), Scalar(11.0 / 84.0),
    ],
  ]
  let b_hat: [Scalar] = [
    Scalar(35.0 / 384.0), Scalar(0.0), Scalar(500.0 / 1113.0), Scalar(125.0 / 192.0),
    Scalar(-2187.0 / 6784.0), Scalar(11.0 / 84.0), Scalar(0.0),
  ]
  let b: [Scalar] = [
    Scalar(5179.0 / 57600.0), Scalar(0.0), Scalar(7571.0 / 16695.0), Scalar(393.0 / 640.0),
    Scalar(-92097.0 / 339200.0), Scalar(187.0 / 2100.0), Scalar(1.0 / 40.0),
  ]
  let p: [[Scalar]] = [
    [
      Scalar(1.0), Scalar(-32272833064.0 / 11282082432.0), Scalar(34969693132.0 / 11282082432.0),
      Scalar(-13107642775.0 / 11282082432.0), Scalar(157015080.0 / 11282082432.0),
    ], [Scalar(0.0), Scalar(0.0), Scalar(0.0), Scalar(0.0), Scalar(0.0)],
    [
      Scalar(0.0), Scalar(1323431896.0 * 100.0 / 32700410799.0),
      Scalar(-2074956840.0 * 100.0 / 32700410799.0), Scalar(914128567.0 * 100.0 / 32700410799.0),
      Scalar(-15701508.0 * 100.0 / 32700410799.0),
    ],
    [
      Scalar(0.0), Scalar(-889289856.0 * 25.0 / 5641041216.0),
      Scalar(2460397220.0 * 25.0 / 5641041216.0), Scalar(-1518414297.0 * 25.0 / 5641041216.0),
      Scalar(94209048.0 * 25.0 / 5641041216.0),
    ],
    [
      Scalar(0.0), Scalar(259006536.0 * 2187.0 / 199316789632.0),
      Scalar(-687873124.0 * 2187.0 / 199316789632.0), Scalar(451824525.0 * 2187.0 / 199316789632.0),
      Scalar(-52338360.0 * 2187.0 / 199316789632.0),
    ],
    [
      Scalar(0.0), Scalar(-361440756.0 * 11.0 / 2467955532.0),
      Scalar(946554244.0 * 11.0 / 2467955532.0), Scalar(-661884105.0 * 11.0 / 2467955532.0),
      Scalar(106151040.0 * 11.0 / 2467955532.0),
    ],
    [
      Scalar(0.0), Scalar(44764047.0 / 29380423.0), Scalar(-127_201_567 / 29380423.0),
      Scalar(90730570.0 / 29380423.0), Scalar(-8293050.0 / 29380423.0),
    ],
  ]
}

public protocol OdeVector: AdditiveArithmetic {
  #if canImport(Numerics)
    /// Scalar type used in the vector
    associatedtype Scalar: Real & BinaryFloatingPoint
  #else
    /// Scalar type used in the vector
    associatedtype Scalar: BinaryFloatingPoint
  #endif
  /// Number of elements in the vector.
  var scalarCount: Int { get }
  /// Access individual elements of the vector.
  subscript(index: Int) -> Self.Scalar { get set }
  /// Create a vector with all elements initialized to the same value.
  init(repeating x: Scalar)
  /// Scalar multiplication of a vector.
  static func * (lhs: Self.Scalar, rhs: Self) -> Self
  /// Compute the infinity norm (maximum absolute value) of the vector.
  func inf_norm() -> Scalar
}

extension OdeVector {
  /// Default implementation for inf_norm
  public func inf_norm() -> Scalar {
    var max: Scalar = abs(self[0])
    // Find the maximum absolute value in the vector.
    for i in 1..<self.scalarCount {
      let abs_data = abs(self[i])
      if abs_data > max { max = abs_data }
    }
    return max
  }
  /// Integrates the ODE using explicit Runge-Kutta method with Dormand-Prince coefficients.
  ///
  /// - Parameters:
  ///   - ts: An array of time points at which to compute the solution.
  ///   - y0: The initial value vector (initial condition) for the ODE.
  ///   - tol: The tolerance value used for controlling the step size in the integration.
  ///   - dydx: A function that takes the current value vector and time, and returns the time derivative vector.
  /// - Returns: An array of computed solution vectors at different time points.
  public static func integrate(
    over ts: [Self.Scalar], y0: Self, tol: Self.Scalar,
    dydx: (Self, Self.Scalar) -> Self
  ) -> [Self] {
    let n = ts.count
    // Create an array to store the solution vectors.
    return [Self](unsafeUninitializedCapacity: n) { buffer, initializedCount in
    // Call explicitRungeKutta to compute the solution vectors and return the number of computed solutions.
      initializedCount = explicitRungeKutta(
        tableau: DormondPrice<Scalar>(), ys: &buffer, ts: ts, y0: y0, dydx: dydx, tol: tol)
    }
  }
}

// Make a Double conform to a OdeVector of size 1
extension Double: OdeVector {
  public typealias Scalar = Double

  public subscript(index: Int) -> Self.Scalar {
    get { return self }
    set { self = newValue }
  }

  public var scalarCount: Int { return 1 }

  public init(repeating x: Scalar) { self = x }

  public func inf_norm() -> Scalar { return abs(self) }
}

#if canImport(Numerics)
  extension SIMD2: OdeVector where Scalar: Real & BinaryFloatingPoint {}
  extension SIMD3: OdeVector where Scalar: Real & BinaryFloatingPoint {}
  extension SIMD4: OdeVector where Scalar: Real & BinaryFloatingPoint {}
  extension SIMD8: OdeVector where Scalar: Real & BinaryFloatingPoint {}
  extension SIMD16: OdeVector where Scalar: Real & BinaryFloatingPoint {}
  extension SIMD32: OdeVector where Scalar: Real & BinaryFloatingPoint {}
  extension SIMD64: OdeVector where Scalar: Real & BinaryFloatingPoint {}
  #if os(macOS) || os(iOS)
    extension SIMD2: AdditiveArithmetic where Scalar: Real & BinaryFloatingPoint {}
    extension SIMD3: AdditiveArithmetic where Scalar: Real & BinaryFloatingPoint {}
    extension SIMD4: AdditiveArithmetic where Scalar: Real & BinaryFloatingPoint {}
    extension SIMD8: AdditiveArithmetic where Scalar: Real & BinaryFloatingPoint {}
    extension SIMD16: AdditiveArithmetic where Scalar: Real & BinaryFloatingPoint {}
    extension SIMD32: AdditiveArithmetic where Scalar: Real & BinaryFloatingPoint {}
    extension SIMD64: AdditiveArithmetic where Scalar: Real & BinaryFloatingPoint {}
  #endif
#else
  extension SIMD2: OdeVector where Scalar: BinaryFloatingPoint {}
  extension SIMD3: OdeVector where Scalar: BinaryFloatingPoint {}
  extension SIMD4: OdeVector where Scalar: BinaryFloatingPoint {}
  extension SIMD8: OdeVector where Scalar: BinaryFloatingPoint {}
  extension SIMD16: OdeVector where Scalar: BinaryFloatingPoint {}
  extension SIMD32: OdeVector where Scalar: BinaryFloatingPoint {}
  extension SIMD64: OdeVector where Scalar: BinaryFloatingPoint {}
  extension SIMD2: AdditiveArithmetic where Scalar: BinaryFloatingPoint {}
  extension SIMD3: AdditiveArithmetic where Scalar: BinaryFloatingPoint {}
  extension SIMD4: AdditiveArithmetic where Scalar: BinaryFloatingPoint {}
  extension SIMD8: AdditiveArithmetic where Scalar: BinaryFloatingPoint {}
  extension SIMD16: AdditiveArithmetic where Scalar: BinaryFloatingPoint {}
  extension SIMD32: AdditiveArithmetic where Scalar: BinaryFloatingPoint {}
  extension SIMD64: AdditiveArithmetic where Scalar: BinaryFloatingPoint {}
#endif
