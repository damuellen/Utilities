//  Copyright 2022 Daniel Müllenborn
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

extension Gnuplot {
  public convenience init<Scalar: FloatingPoint>(y1: [[Scalar]], y2: [[Scalar]])
  where Scalar: LosslessStringConvertible {
    self.init(y1s: [y1], y2s: [y2])
  }
  public convenience init<Series: Sequence, Scalar: FloatingPoint>(xys: Series..., labels: [String]..., titles: [String] = [], style: Style = .linePoints)
  where Series.Element == SIMD2<Scalar>, Scalar: LosslessStringConvertible {
    self.init(xys: xys.map { xy in xy.map { [$0.x, $0.y] } }, xylabels: labels, titles: titles, style: style)
  }
  public convenience init<Series: Sequence, Scalar: FloatingPoint>(xys: Series..., labels: [String]..., titles: [String] = [], style: Style = .linePoints)
  where Series.Element == [Scalar], Scalar: LosslessStringConvertible {
    self.init(xys: xys.map { xy in xy.map { $0 } }, xylabels: labels, titles: titles, style: style)
  }
  @_disfavoredOverload public convenience init<Series: Sequence, Scalar: FloatingPoint>(xs: Series..., ys: Series..., labels: [String]..., titles: String..., style: Style = .linePoints)
  where Series.Element == Scalar, Scalar: LosslessStringConvertible {
    self.init(xys: zip(xs, ys).map { a, b in zip(a, b).map { [$0, $1] } }, xylabels: labels, titles: titles, style: style)
  }
  public convenience init<Series: Collection, Scalar: FloatingPoint>(xs: Series, ys: Series..., labels: [String]..., titles: String..., style: Style = .linePoints)
  where Series.Element == Scalar, Scalar: LosslessStringConvertible {
    let xys = xs.indices.map { index -> [Scalar] in [xs[index]] + ys.map { $0[index] } }
    self.init(xys: [xys], xylabels: labels, titles: titles, style: style)
  }
  public convenience init<Series: Sequence, Scalar: FloatingPoint>(ys: Series..., labels: [String]..., titles: String..., style: Style = .linePoints)
  where Series.Element == Scalar, Scalar: LosslessStringConvertible {
    self.init(xys: ys.map { $0.map { [$0] } }, xylabels: labels, titles: titles, style: style)
  }
  public convenience init<Scalar: FloatingPoint>(xy1s: [[Scalar]]..., xy2s: [[Scalar]]..., titles: String..., style: Style = .linePoints)
  where Scalar: LosslessStringConvertible {
    self.init(xy1s: xy1s, xy2s: xy2s, titles: titles, style: style)
  }
}

@available(macOS 10.12, *)
extension DateInterval {
  public static let Hour = DateInterval(start: .init(timeIntervalSinceReferenceDate: 0), duration: 3600)
  public static let Day = DateInterval(start: .init(timeIntervalSinceReferenceDate: 0), duration: 86400)
  public static let Week = DateInterval(start: .init(timeIntervalSinceReferenceDate: 0), duration: 604800)
  public static let Jan = DateInterval(start: .init(timeIntervalSinceReferenceDate: 0), duration: 86400 * 31)
  public static let Feb = DateInterval(start: .init(timeIntervalSinceReferenceDate: 86400 * 31), duration: 86400 * 28)
  public static let Mar = DateInterval(start: .init(timeIntervalSinceReferenceDate: 86400 * 59), duration: 86400 * 31)
  public static let Apr = DateInterval(start: .init(timeIntervalSinceReferenceDate: 86400 * 90), duration: 86400 * 30)
  public static let May = DateInterval(start: .init(timeIntervalSinceReferenceDate: 86400 * 120), duration: 86400 * 31)
  public static let Jun = DateInterval(start: .init(timeIntervalSinceReferenceDate: 86400 * 151), duration: 86400 * 30)
  public static let Jul = DateInterval(start: .init(timeIntervalSinceReferenceDate: 86400 * 181), duration: 86400 * 31)
  public static let Aug = DateInterval(start: .init(timeIntervalSinceReferenceDate: 86400 * 212), duration: 86400 * 31)
  public static let Sep = DateInterval(start: .init(timeIntervalSinceReferenceDate: 86400 * 243), duration: 86400 * 30)
  public static let Oct = DateInterval(start: .init(timeIntervalSinceReferenceDate: 86400 * 273), duration: 86400 * 31)
  public static let Nov = DateInterval(start: .init(timeIntervalSinceReferenceDate: 86400 * 304), duration: 86400 * 30)
  public static let Dec = DateInterval(start: .init(timeIntervalSinceReferenceDate: 86400 * 334), duration: 86400 * 31)
}
