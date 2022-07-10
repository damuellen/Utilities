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
  public convenience init<T: FloatingPoint>(y1: [[T]], y2: [[T]]) { self.init(y1s: [y1], y2s: [y2]) }
  public convenience init<S: Sequence, F: FloatingPoint>(xys: S..., labels: [String]..., titles: [String] = [], style: Style = .linePoints) where S.Element == SIMD2<F> {
    self.init(xys: xys.map { xy in xy.map { [$0.x, $0.y] } }, xylabels: labels, titles: titles, style: style) 
  }
  public convenience init<S: Sequence, F: FloatingPoint>(xys: S..., labels: [String]..., titles: [String] = [], style: Style = .linePoints) where S.Element == [F] {
    self.init(xys: xys.map { xy in xy.map { $0 } }, xylabels: labels, titles: titles, style: style)
  }
  @_disfavoredOverload public convenience init<S: Sequence, F: FloatingPoint>(xs: S..., ys: S..., labels: [String]..., titles: String..., style: Style = .linePoints) where S.Element == F {
    self.init(xys: zip(xs, ys).map { a, b in zip(a, b).map { [$0, $1] } }, xylabels: labels, titles: titles, style: style)
  }
  public convenience init<S: Collection, F: FloatingPoint>(xs: S, ys: S..., labels: [String]..., titles: String..., style: Style = .linePoints) where S.Element == F {
    let xys = xs.indices.map { index -> [F] in [xs[index]] + ys.map { $0[index] } }
    self.init(xys: [xys], xylabels: labels, titles: titles, style: style)
  }
  public convenience init<S: Sequence, F: FloatingPoint>(ys: S..., labels: [String]..., titles: String..., style: Style = .linePoints) where S.Element == F {
    self.init(xys: ys.map { $0.map { [$0] } }, xylabels: labels, titles: titles, style: style)
  }
  public convenience init<T: FloatingPoint>(xy1s: [[T]]..., xy2s: [[T]]..., titles: String..., style: Style = .linePoints) {
    self.init(xy1s: xy1s, xy2s: xy2s, titles: titles, style: style)
  }
  @available(macOS 10.12, *)
  public convenience init<S: Sequence, F: FloatingPoint>(y1s: S..., y2s: S..., titles: [String] = [], range: DateInterval) where S.Element == F {
    self.init(y1s: y1s.map(Array.init), y2s: y2s.map(Array.init), titles: titles, range: range)
  }
}
