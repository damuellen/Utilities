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

#if canImport(Cocoa)
import Cocoa
#endif
/// Create graphs using gnuplot.
public final class Gnuplot {
  #if canImport(Cocoa)
  public var image: NSImage? { try? NSImage(data: self(.pngSmall(path: ""))) }
  #endif
  public var svg: String? {
    var last = UInt8(0)
    guard
      let string = try? self(.svg(path: ""))
        .drop(while: {
          if last == UInt8(ascii: ">") { return false }
          last = $0
          return true
        })
    else { return nil }
    return String(decoding: string, as: Unicode.UTF8.self)
  }
  public init(data: String) {
    self.datablock = data
    self.plot = "$data"
    self.settings = [:]
  }
  public static func process() -> Process {
    let gnuplot = Process()
    #if os(Windows)
    gnuplot.executableURL = URL(fileURLWithPath: "C:/bin/gnuplot.exe")
    #elseif os(Linux)
    gnuplot.executableURL = .init(fileURLWithPath: "/usr/bin/gnuplot")
    #else
    gnuplot.executableURL = .init(fileURLWithPath: "/opt/homebrew/bin/gnuplot")
    #endif
    gnuplot.standardInput = Pipe()
    gnuplot.standardOutput = Pipe()
    return gnuplot
  }
  /// Execute the plot commands.
  @discardableResult public func callAsFunction(_ terminal: Terminal) throws -> Data {
    let process = Gnuplot.process()
    let stdin = process.standardInput as! Pipe
    try process.run()
    stdin.fileHandleForWriting.write(commands(terminal).data(using: .utf8)!)
    stdin.fileHandleForWriting.closeFile()
    let stdout = process.standardOutput as! Pipe
    return stdout.fileHandleForReading.readDataToEndOfFile()
  }
  public func commands(_ terminal: Terminal) -> String {
    let config: String
    if case .svg = terminal { config = (settings.concatenated + SVG.concatenated) } 
    else if case .pdf = terminal { config = (settings.concatenated + PDF.concatenated) }
    else { config = (settings.concatenated + PNG.concatenated + SVG.concatenated) }
    let command = userCommand ?? "\nplot " + plot
    return datablock + terminal.output + config + command + "\nexit\n\n"
  }
  public func set(title: String) -> Self {
    settings["title"] = "'\(title)'"
    return self
  }
  public func set(xlabel: String) -> Self {
    settings["xlabel"] = "'\(xlabel)'"
    return self
  }
  public func set(ylabel: String) -> Self {
    settings["ylabel"] = "'\(ylabel)'"
    return self
  }
  static private func settings(_ style: Style) -> [String: String] {
    let lw: String
    let ps: String
    if case .points = style {
      lw = "lw 2"
      ps = "ps 1.0"
    } else {
      lw = "lw 1.5"
      ps = "ps 1.2"
    }
    var points = Array(1...7).shuffled()
    let dict = [
      "style line 11":"lt 1 \(lw) pt \(points.removeLast()) \(ps) lc rgb '#0072bd'",
      "style line 12":"lt 1 \(lw) pt \(points.removeLast()) \(ps) lc rgb '#d95319'",
      "style line 13":"lt 1 \(lw) pt \(points.removeLast()) \(ps) lc rgb '#edb120'",
      "style line 14":"lt 1 \(lw) pt \(points.removeLast()) \(ps) lc rgb '#7e2f8e'",
      "style line 15":"lt 1 \(lw) pt \(points.removeLast()) \(ps) lc rgb '#77ac30'",
      "style line 16":"lt 1 \(lw) pt \(points.removeLast()) \(ps) lc rgb '#4dbeee'",
      "style line 17":"lt 1 \(lw) pt \(points.removeLast()) \(ps) lc rgb '#a2142f'",
      "style line 18":"lt 1 lw 1 dashtype 3 lc rgb 'black'", 
      "style line 19":"lt 0 lw 0.5 lc rgb 'black'",      
      "style line 21":"lt 1 lw 3 pt 9 ps 0.8 lc rgb '#0072bd'",
      "style line 22":"lt 1 lw 3 pt 9 ps 0.8 lc rgb '#d95319'",
      "style line 23":"lt 1 lw 3 pt 9 ps 0.8 lc rgb '#edb120'",
      "style line 24":"lt 1 lw 3 pt 9 ps 0.8 lc rgb '#7e2f8e'",
      "style line 25":"lt 1 lw 3 pt 9 ps 0.8 lc rgb '#77ac30'",
      "style line 26":"lt 1 lw 3 pt 9 ps 0.8 lc rgb '#4dbeee'",
      "style line 27":"lt 1 lw 3 pt 9 ps 0.8 lc rgb '#a2142f'",
      "label":"textcolor rgb 'black'",
      "key":"above tc ls 18",
    ]
    return dict
  }
  public var settings: [String: String]
  public var userCommand: String? = nil

  public init(temperatures: String) {
    self.settings = Gnuplot.settings(.linePoints).merging(
      ["term": "svg size 1280,800", 
      "xtics": "10", 
      "ytics": "10",
      "xlabel": "'Q̇ [MW]' textcolor rgb 'black'",
      "ylabel": "'Temperatures [°C]' textcolor rgb 'black'"]
    ) { (_, new) in new }

    self.datablock = "\n$data <<EOD\n" + temperatures + "\n\n\nEOD\n"
    self.plot = """
        $data i 0 u 1:2 w lp ls 11 title columnheader(1), \
        $data i 1 u 1:2 w lp ls 12 title columnheader(1), \
        $data i 2 u 1:2 w lp ls 13 title columnheader(1), \
        $data i 3 u 1:2 w lp ls 15 title columnheader(1), \
        $data i 4 u 1:2 w lp ls 14 title columnheader(1), \
        $data i 5 u 1:2 w lp ls 14 title columnheader(1), \
        $data i 0 u 1:2:(sprintf("%d°C", $2)) with labels tc ls 18 offset char 3,0 notitle, \
        $data i 2 u 1:2:(sprintf("%d°C", $2)) with labels tc ls 18 offset char 3,0 notitle, \
        $data i 3 u 1:2:(sprintf("%d°C", $2)) with labels tc ls 18 offset char 3,0 notitle, \
        $data i 4 u 1:2:(sprintf("%d°C", $2)) with labels tc ls 18 offset char 3,0 notitle, \
        $data i 5 u 1:2:(sprintf("%d°C", $2)) with labels tc ls 18 offset char 3,0 notitle
      """
  }
  public init<T: FloatingPoint>(xys: [[[T]]], titles: [String] = [], style: Style = .linePoints) {
    let missingTitles = xys.count - titles.count
    var titles = titles
    if missingTitles > 0 { titles.append(contentsOf: repeatElement("-", count: missingTitles)) }
    self.settings = Gnuplot.settings(style)
    let data = zip(titles, xys).map { title, xys in title + "\n" + separated(xys) }
    self.datablock = "\n$data <<EOD\n" + data.joined(separator: "\n\n\n") + "\n\n\nEOD\n"
    let (s, l) = style.raw
    self.plot = xys.indices
      .map { i in
        if (xys[i].first?.count ?? 0) > 1 {
          return (2...xys[i][0].count).map { c in "$data i \(i) u 1:\(c) \(s) w \(l) ls \(i+c+9) title columnheader(1)" }.joined(separator: ", \\\n")
        } else {
          return "$data i \(i) u 0:1 \(s) w \(l) ls \(i+11) title columnheader(1)"
        }
      }
      .joined(separator: ", \\\n")
  }
  public init<T: FloatingPoint>(xy1s: [[[T]]], xy2s: [[[T]]] = [], titles: [String] = [], style: Style = .linePoints) {
    let missingTitles = xy1s.count + xy2s.count - titles.count
    var titles = titles
    if missingTitles > 0 { titles.append(contentsOf: repeatElement("-", count: missingTitles)) }
    self.settings = Gnuplot.settings(style).merging(["ytics": "nomirror", "y2tics": ""]) { (_, new) in new }
    let y1 = zip(titles, xy1s).map { t, xys in t + "\n" + separated(xys) }
    let y2 = zip(titles.dropFirst(xy1s.count), xy2s).map { t, xys in t + " ,\n" + separated(xys) }
    self.datablock = "\n$data <<EOD\n" + y1.joined(separator: "\n\n\n") + (xy2s.isEmpty ? "" : "\n\n\n") + y2.joined(separator: "\n\n\n") + "\n\n\nEOD\n"
    let (s, l) = style.raw
    self.plot =
      xy1s.indices
      .map { i in
        if (xy1s[i].first?.count ?? 0) > 1 {
          return (2...xy1s[i][0].count).map { c in "$data i \(i) u 1:\(c) \(s) axes x1y1 w \(l) ls \(i+c+9) title columnheader(1)" }.joined(separator: ", \\\n")
        } else {
          return "$data i \(i) u 0:1 \(s) axes x1y1 w \(l) ls \(i+11) title columnheader(1)"
        }
      }
      .joined(separator: ", \\\n") + ", \\\n"
      + xy2s.indices
      .map { i in
        if (xy2s[i].first?.count ?? 0) > 1 {
          return (2...xy2s[i][0].count).map { c in "$data i \(i + xy1s.endIndex) u 1:\(c) \(s) axes x1y2 w \(l) ls \(i+c+19) title columnheader(1)" }.joined(separator: ", \\\n")
        } else {
          return "$data i \(i + xy1s.endIndex) u 0:1 \(s) axes x1y2 w \(l) ls \(i+21) title columnheader(1)"
        }
      }
      .joined(separator: ", \\\n")
  }
  public convenience init<S: Sequence, F: FloatingPoint>(xys: S..., titles: [String] = [], style: Style = .linePoints) where S.Element == SIMD2<F> { self.init(xys: xys.map { xy in xy.map { [$0.x, $0.y] } }, titles: titles, style: style) }
  public convenience init<S: Sequence, F: FloatingPoint>(xys: S..., titles: [String] = [], style: Style = .linePoints) where S.Element == [F] { self.init(xys: xys.map { xy in xy.map { $0 } }, titles: titles, style: style) }
  #if swift(>=5.4)
  public convenience init<S: Collection, F: FloatingPoint>(xs: S..., ys: S..., titles: String..., style: Style = .linePoints) where S.Element == F {
    if ys.isEmpty {
      self.init(xys: xs.map { $0.map { [$0] } }, titles: titles, style: style)
    } else if xs.count == 1, ys.count > 1, !ys.map(\.count).contains(where: { $0 != xs[0].count }) {
      let xys = xs[0].indices.map { index in [xs[0][index]] + ys.map { $0[index] } }
      self.init(xys: xys, titles: titles, style: style)
    } else {
      self.init(xys: zip(xs, ys).map { a, b in zip(a, b).map { [$0, $1] } }, titles: titles, style: style)
    }
  }
  public convenience init<X: Collection, Y: Collection, F: FloatingPoint, S: SIMD>(xs: X, ys: Y, titles: String..., style: Style = .linePoints) where X.Element == F, Y.Element == S, S.Scalar == F {
    let xys = ys.first!.indices.map { i in zip(xs, ys).map { [$0.0, $0.1[i]] } }
    self.init(xys: xys, titles: titles, style: style)
  }
  public convenience init<T: FloatingPoint>(xy1s: [[T]]..., xy2s: [[T]]..., titles: String..., style: Style = .linePoints) { self.init(xy1s: xy1s, xy2s: xy2s, titles: titles, style: style) }
  #endif
  public enum Style {
    case lines(smooth: Bool)
    case linePoints
    case points
    var raw: (String, String) {
      let s: String
      let l: String
      switch self {
      case .lines(let smooth):
        s = smooth ? "smooth csplines" : ""
        l = "l"
      case .linePoints:
        s = ""
        l = "lp"
      case .points:
        s = ""
        l = "points"
      }
      return (s, l)
    }
  }
  public enum Terminal {
    case svg(path: String)
    case pdf(path: String)
    case png(path: String)
    case pngSmall(path: String)
    case pngLarge(path: String)
    var output: String {
      #if os(Linux)
      let font = "font 'Times,"
      #else
      let font = "font 'Arial,"
      #endif
      switch self {
      case .svg(let path):
        #if os(Windows)
        let height = 600
        #elseif os(Linux)
        let height = 750
        #else
        let height = 710
        #endif
        return "set term svg size 1000,\(height)\n" + "set output \(path.isEmpty ? "" : ("'" + path + "'"))\n"
      case .pdf(let path): return "set term pdfcairo size 10,7.1 enhanced \(font)14'\n" + "set output \(path.isEmpty ? "" : ("'" + path + "'"))\n"
      case .png(let path): return "set term pngcairo size 1440, 900 enhanced \(font)12'\n" + "set output \(path.isEmpty ? "" : ("'" + path + "'"))\n"
      case .pngSmall(let path): return "set term pngcairo size 1024, 720 enhanced \(font)12'\n" + "set output \(path.isEmpty ? "" : ("'" + path + "'"))\n"
      case .pngLarge(let path): return "set term pngcairo size 1920, 1200 enhanced \(font)14'\n" + "set output \(path.isEmpty ? "" : ("'" + path + "'"))\n"
      }
    }
  }
  private let datablock: String
  private let plot: String
  private let SVG = ["border 31 lw 0.5 lc rgb 'black'", "grid ls 19"]
  private let PDF = ["border 31 lw 1 lc rgb 'black'", "grid ls 18"]
  private let PNG = ["object rectangle from graph 0,0 to graph 1,1 behind fillcolor rgb '#EBEBEB' fillstyle solid noborder"]
}

private func separated<T: FloatingPoint>(_ xys: [[T]]) -> String { xys.map { xy in xy.map { "\($0)" }.joined(separator: " ") }.joined(separator: "\n") }
extension Array where Element == String { var concatenated: String { self.map { "set " + $0 + "\n" }.joined() } }
extension Dictionary where Key == String, Value == String { var concatenated: String { self.map { "set " + $0.key + " " + $0.value + "\n" }.joined() } }
@inlinable public func solve(inDomain range: ClosedRange<Double>, step: Double, f: (Double) -> Double) -> [[Double]] { stride(from: range.lowerBound, through: range.upperBound, by: step).map { [$0, f($0)] } }
