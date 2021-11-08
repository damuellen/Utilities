//
//  Copyright 2021 Daniel Müllenborn
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//

import Libc

precedencegroup ExponentiationPrecedence {
  associativity: right
  higherThan: MultiplicationPrecedence
}

infix operator **: ExponentiationPrecedence
infix operator **=: AssignmentPrecedence

public extension Double {
  static func ** (lhs: Double, rhs: Double) -> Double {
    return pow(lhs, rhs)
  }

  static func **= (lhs: inout Double, rhs: Double) {
    lhs = lhs ** rhs
  }
}

public func * (lhs: String, rhs: String) -> String {
  var width = terminalWidth()
  width.clamp(to: 70...100)
  var c = width - lhs.count - rhs.count - 1
  c = c < 0 ? 1 : c
  return lhs + String(repeating: " ", count: c) + rhs + "\n"
}

infix operator |>

public func |> <T, U>(value: T, function: ((T)-> U)) -> U {
    return function(value)
}
