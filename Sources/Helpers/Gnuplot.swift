//  Copyright 2021 Daniel Müllenborn
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

#if canImport(Cocoa)
import Cocoa
#endif
#if canImport(PythonKit)
import PythonKit
#endif
/// Create graphs using gnuplot.
public final class Gnuplot: CustomStringConvertible {
  #if canImport(Cocoa)
  public var image: NSImage? {
    guard let data = try? callAsFunction(.pngSmall(path: "")) else { return nil }
    #if swift(>=5.4)
    return NSImage(data: data)
    #else
    return NSImage(data: data!)
    #endif
  }
  #endif
  #if canImport(PythonKit)
  @discardableResult public func display() -> Gnuplot {
    settings["term"] = "svg size \(width),\(height)"
    settings["object"] = "rectangle from graph 0,0 to graph 1,1 behind fillcolor rgb '#EBEBEB' fillstyle solid noborder"
    guard let svg = svg else { return self }
    settings.removeValue(forKey: "term")
    settings.removeValue(forKey: "object")
    let display = Python.import("IPython.display")
    display.display(display.SVG(data: svg))
    return self
  }
  #endif
  public var svg: String? {
    do { 
      guard let data = try callAsFunction(.svg(path: "")) else { return nil }
      let svg = data.dropFirst(270)
      return #"<svg width="\#(width+25)" height="\#(height)" viewBox="0 0 \#(width+25) \#(height)" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">"#
      + String(decoding: svg, as: Unicode.UTF8.self)
    } catch { 
      print(error)
      return nil 
    }
  }
  public init(data: String, style: Style = .linePoints) {
    self.datablock = "\n$data <<EOD\n" + data + "\n\n\nEOD\n\n"
    self.defaultPlot = "plot $data"
    self.settings = Gnuplot.settings(style)
  }
  public init(plot: String, style: Style = .linePoints) {
    self.datablock = ""
    self.defaultPlot = plot
    self.settings = Gnuplot.settings(style)
  }
  #if os(Linux)
  deinit {
    if let process = Gnuplot.running, process.isRunning {
      let stdin = process.standardInput as! Pipe
      stdin.fileHandleForWriting.write("\nexit\n".data(using: .utf8)!)
      process.waitUntilExit()
      Gnuplot.running = nil
    }
  }
  private static var running: Process?
  #endif
  #if os(iOS)
  @discardableResult public func callAsFunction(_ terminal: Terminal) throws -> Data? {
    commands(terminal).data(using: .utf8)
  }
  #else
  public static func process() -> Process {
    #if os(Linux)
    if let process = Gnuplot.running { if process.isRunning { return process } }
    let gnuplot = Process()
    gnuplot.executableURL = "/usr/bin/gnuplot"
    gnuplot.arguments = ["--persist"]
    Gnuplot.running = gnuplot
    #else
    let gnuplot = Process()
    #endif
    #if os(Windows)
    gnuplot.executableURL = "C:/bin/gnuplot.exe"
    #elseif os(macOS)
    if #available(macOS 10.13, *) {
      gnuplot.executableURL = "/opt/homebrew/bin/gnuplot"
    } else {
      gnuplot.launchPath = "/opt/homebrew/bin/gnuplot"
    }
    #endif
    #if !os(Windows)
    gnuplot.standardInput = Pipe()
    #endif
    gnuplot.standardOutput = Pipe()
    gnuplot.standardError = nil
    return gnuplot
  }
  #endif
  #if os(Windows)
  @discardableResult public func callAsFunction(_ terminal: Terminal) throws -> Data? {
    let gnuplot = Gnuplot.process()
    let plot = URL.temporaryFile().appendingPathExtension("plot")    
    try commands(terminal).data(using: .utf8)!.write(to: plot)
    gnuplot.arguments = [plot.path]
    try gnuplot.run()
    let stdout = gnuplot.standardOutput as! Pipe
    let data = try stdout.fileHandleForReading.readToEnd()
    try plot.removeItem()
    return data
  }
  #elseif !os(iOS)
  /// Execute the plot commands.
  @discardableResult public func callAsFunction(_ terminal: Terminal) throws -> Data? {
    let gnuplot = Gnuplot.process()
    if #available(macOS 10.13, *) {
    if !gnuplot.isRunning { try gnuplot.run() }
    } else {
    if !gnuplot.isRunning { gnuplot.launch() }
    }
    let stdin = gnuplot.standardInput as! Pipe
    stdin.fileHandleForWriting.write(commands(terminal).data(using: .utf8)!)
    let stdout = gnuplot.standardOutput as! Pipe
    #if os(Linux)
    let endOfData: Data
    if case .svg(let path) = terminal, path.isEmpty {
      endOfData = "</svg>\n\n".data(using: .utf8)!
    } else if case .pdf(let path) = terminal, path.isEmpty {
      endOfData = Data([37,37,69,79,70,10]) // %%EOF
    } else if case .pngSmall(let path) = terminal, path.isEmpty {
      endOfData = Data([73,69,78,68,174,66,96,130]) // IEND
    } else {
      return nil
    }
    var data = Data()
    while data.suffix(endOfData.count) != endOfData {
      data.append(stdout.fileHandleForReading.availableData)
    }
    return data
    #else
    if #available(macOS 10.15.4, *) {
      try stdin.fileHandleForWriting.close()
      return try stdout.fileHandleForReading.readToEnd()
    } else {
      stdin.fileHandleForWriting.closeFile()
      return stdout.fileHandleForReading.readDataToEndOfFile()
    }
    #endif
  }
  #endif
  public func commands(_ terminal: Terminal? = nil) -> String {
    let config: String
    if let terminal = terminal {  
      if case .svg = terminal {
        config = settings.merging(terminal.output){old,_ in old}.concatenated + SVG.concatenated } 
      else if case .pdf = terminal {
        config = settings.merging(terminal.output){old,_ in old}.concatenated + PDF.concatenated }
      else { 
        config = settings.merging(terminal.output){old,_ in old}.concatenated + PNG.concatenated + SVG.concatenated
      }
    } else {
      config = settings.concatenated
    }
    let plot = userPlot ?? defaultPlot
    if multiplot > 1 {
      let layout: (rows: Int, cols: Int)
      if multiplot == 9 { layout = (3, 3) } else {
        let z = multiplot.quotientAndRemainder(dividingBy: 2)
        let (x,y) = (z.quotient, (multiplot / z.quotient))
        layout = (min(x,y), max(x,y) + (x > 1 && z.remainder > 0 ? 1 : 0))
      }
      return datablock + config + "\n"
        + "set multiplot layout \(layout.rows),\(layout.cols) rowsfirst\n"
        + plot + "\nreset session\nunset multiplot\n"
    }
    return datablock + config + "\n" + plot + "\nreset session\n"
  }
  public var description: String { commands() }
  public var settings: [String: String]
  public var userPlot: String? = nil

  @discardableResult public func plot(
    multi: Bool = false, index i: Int = 0, x: Int = 1, y: Int = 2, style: Style = .linePoints
  ) -> Self {
    let (s, l) = style.raw
    multiplot += multi ? 1 : 0
    let command = "$data i \(i) u \(x):\(y) \(s) w \(l) ls \(Int.random(in: 11...17)) title columnheader(1)"
    if let plot = userPlot {
      userPlot = plot + (multi ? "\nplot " : ", ") + command
    } else {  
      userPlot = "plot " + command
    }
    return self
  }

  @discardableResult public func plot(
    index i: Int = 0, x: Int = 1, y: Int = 2, label: Int, rotate: Int = 45, offset: String = "3,1.5"
  ) -> Self {
    let command = "$data i \(i) u \(x):\(y):\(label) with labels tc ls 18 rotate by \(rotate) offset \(offset) notitle"
    if let plot = userPlot {
      userPlot = plot + ", " + command
    } else {  
      userPlot = "plot " + command
    }
    return self
  }
  @discardableResult public func set(title: String) -> Self {
    settings["title"] = "'\(title)'"
    return self
  }
  @discardableResult public func set(xlabel: String) -> Self {
    settings["xlabel"] = "'\(xlabel)'"
    return self
  }
  @discardableResult public func set(ylabel: String) -> Self {
    settings["ylabel"] = "'\(ylabel)'"
    return self
  }
  @discardableResult public func set<T: FloatingPoint>(xrange x: ClosedRange<T>) -> Self {
    settings["xrange"] = "\(x.lowerBound):\(x.upperBound)"
    return self
  }
  @discardableResult public func set<T: FloatingPoint>(yrange y: ClosedRange<T>) -> Self {
    settings["yrange"] = "\(y.lowerBound):\(y.upperBound)"
    return self
  }
  private static func settings(_ style: Style) -> [String: String] {
    let lw: String
    let ps: String
    if case .points = style {
      lw = "lw 1.5"
      ps = "ps 1.0"
    } else {
      lw = "lw 1.5"
      ps = "ps 1.0"
    }
    let pt = Array(1...7).shuffled()
    let dict = [
      "style line 11":"lt 1 \(lw) pt \(pt[0]) \(ps) lc rgb '#0072bd'",
      "style line 12":"lt 1 \(lw) pt \(pt[1]) \(ps) lc rgb '#d95319'",
      "style line 13":"lt 1 \(lw) pt \(pt[2]) \(ps) lc rgb '#edb120'",
      "style line 14":"lt 1 \(lw) pt \(pt[3]) \(ps) lc rgb '#7e2f8e'",
      "style line 15":"lt 1 \(lw) pt \(pt[4]) \(ps) lc rgb '#77ac30'",
      "style line 16":"lt 1 \(lw) pt \(pt[5]) \(ps) lc rgb '#4dbeee'",
      "style line 17":"lt 1 \(lw) pt \(pt[6]) \(ps) lc rgb '#a2142f'",
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
  
  public init<T: FloatingPoint>(y1s: [[[T]]], y2s: [[[T]]]) {
    self.datablock = "\n$data <<EOD\n" 
      + y1s.map { separated($0.transposed()) }.joined(separator: "\n\n\n")
      + "\n\n\n"
      + y2s.map { separated($0.transposed()) }.joined(separator: "\n\n\n")
      + "\n\n\nEOD\n\n"
    let setting = [
      "key": "off", "xdata": "time", "timefmt": "'%s'", "format x": "'%k'",
      "xtics": "21600 ", "yrange": "0:1", "ytics": "0.2", "term": "pdfcairo size 7.1, 10",
    ]
    self.settings = Gnuplot.settings(.lines(smooth: false)).merging(setting){_,new in new}
    let y = y1s.count
    self.defaultPlot = y1s.indices.map { i in
      "\nset multiplot layout 8,4 rowsfirst\n"
        + (1...y1s[i].count).map { c in 
        "plot $data i \(i) u ($0*300):\(c) axes x1y1 w l ls 30, $data i \(i+y) u ($0*300):\(c) axes x1y2 w l ls 31" 
        }.joined(separator: "\n") + "\nunset multiplot"
    }.joined(separator: "\n")
  }
  
  public init<T: FloatingPoint>(xys: [[[T]]], xylabels: [[String]] = [], titles: [String] = [], style: Style = .linePoints) {
    let missingTitles = xys.count - titles.count
    var titles = titles
    if missingTitles > 0 { titles.append(contentsOf: repeatElement("-", count: missingTitles)) }
    let data: [String] = xys.indices.map { i -> String in
      let header: String
      if (xys[i].first?.count ?? 0) == titles.count {
        header = "x " + titles.joined(separator: " ")
      } else {
        header = titles[i]
      }
      return header + "\n" + (xylabels.endIndex > i ? separated(xys[i], labels: xylabels[i]) : separated(xys[i]))
    }
    self.datablock = "\n$data <<EOD\n" + data.joined(separator: "\n\n\n") + "\n\n\nEOD\n\n"
    self.settings = Gnuplot.settings(style)
    let (s, l) = style.raw
    self.defaultPlot = "plot " + xys.indices
      .map { i -> String in
        let columns = xys[i].first?.count ?? 0
        if columns > 1 {
          if columns - 1  == titles.count {
            return (2...xys[i][0].count).map { c in "$data i \(i) u 1:\(c) \(s) w \(l) ls \(i+c+9) title columnheader(c)" }.joined(separator: ", \\\n")
          }
          return (2...xys[i][0].count).map { c in "$data i \(i) u 1:\(c) \(s) w \(l) ls \(i+c+9) title columnheader(1)" }.joined(separator: ", \\\n")
        } else {
          return "$data i \(i) u 0:1 \(s) w \(l) ls \(i+11) title columnheader(1)"
        }
      }
      .joined(separator: ", \\\n") + (xylabels.isEmpty ? "" : ", \\\n" + xylabels.indices.map { i in
        "$data i \(i) u 1:2:3 with labels tc ls 18 offset char 0,1 notitle"
      }.joined(separator: ", \\\n"))
  }

  public init<T: FloatingPoint>(xy1s: [[[T]]], xy2s: [[[T]]] = [], titles: [String] = [], style: Style = .linePoints) {
    let missingTitles = xy1s.count + xy2s.count - titles.count
    var titles = titles
    if missingTitles > 0 { titles.append(contentsOf: repeatElement("-", count: missingTitles)) }
    self.settings = Gnuplot.settings(style).merging(["ytics": "nomirror", "y2tics": ""]) { (_, new) in new }
    let y1: [String] = zip(titles, xy1s).map { t, xys -> String in t + "\n" + separated(xys) }
    let y2: [String] = zip(titles.dropFirst(xy1s.count), xy2s).map { t, xys -> String in t + " ,\n" + separated(xys) }
    self.datablock = "\n$data <<EOD\n" + y1.joined(separator: "\n\n\n") + (xy2s.isEmpty ? "" : "\n\n\n") + y2.joined(separator: "\n\n\n") + "\n\n\nEOD\n\n"
    let (s, l) = style.raw
    self.defaultPlot = "plot " +
      xy1s.indices
      .map { i -> String in
        if (xy1s[i].first?.count ?? 0) > 1 {
          return (2...xy1s[i][0].count).map { c in "$data i \(i) u 1:\(c) \(s) axes x1y1 w \(l) ls \(i+c+9) title columnheader(1)" }.joined(separator: ", \\\n")
        } else {
          return "$data i \(i) u 0:1 \(s) axes x1y1 w \(l) ls \(i+11) title columnheader(1)"
        }
      }
      .joined(separator: ", \\\n") + ", \\\n"
      + xy2s.indices
      .map { i -> String in
        if (xy2s[i].first?.count ?? 0) > 1 {
          return (2...xy2s[i][0].count).map { c in "$data i \(i + xy1s.endIndex) u 1:\(c) \(s) axes x1y2 w \(l) ls \(i+c+19) title columnheader(1)" }.joined(separator: ", \\\n")
        } else {
          return "$data i \(i + xy1s.endIndex) u 0:1 \(s) axes x1y2 w \(l) ls \(i+21) title columnheader(1)"
        }
      }
      .joined(separator: ", \\\n")
  }
  public convenience init<T: FloatingPoint>(y1: [[T]], y2: [[T]]) { self.init(y1s: [y1], y2s: [y2]) }
  public convenience init<S: Sequence, F: FloatingPoint>(xys: S..., labels: [String]..., titles: [String] = [], style: Style = .linePoints) where S.Element == SIMD2<F> {
    self.init(xys: xys.map { xy in xy.map { [$0.x, $0.y] } }, xylabels: labels, titles: titles, style: style) 
  }
  public convenience init<S: Sequence, F: FloatingPoint>(xys: S..., labels: [String]..., titles: [String] = [], style: Style = .linePoints) where S.Element == [F] {
    self.init(xys: xys.map { xy in xy.map { $0 } }, xylabels: labels, titles: titles, style: style)
  }
  @_disfavoredOverload public convenience init<S: Collection, F: FloatingPoint>(xs: S..., ys: S..., labels: [String]..., titles: String..., style: Style = .linePoints) where S.Element == F {
    self.init(xys: zip(xs, ys).map { a, b in zip(a, b).map { [$0, $1] } }, xylabels: labels, titles: titles, style: style)
  }
  public convenience init<S: Collection, F: FloatingPoint>(xs: S, ys: S..., labels: [String]..., titles: String..., style: Style = .linePoints) where S.Element == F {
    let xys = xs.indices.map { index in [xs[index]] + ys.map { $0[index] } }
    self.init(xys: xys, titles: titles, style: style)
  }
  public convenience init<S: Collection, F: FloatingPoint>(xs: S..., labels: [String]..., titles: String..., style: Style = .linePoints) where S.Element == F {
    self.init(xys: xs.map { $0.map { [$0] } }, titles: titles, style: style)
  }
  public convenience init<T: FloatingPoint>(xy1s: [[T]]..., xy2s: [[T]]..., titles: String..., style: Style = .linePoints) {
    self.init(xy1s: xy1s, xy2s: xy2s, titles: titles, style: style)
  }
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
    var output: [String:String] {
      #if os(Linux)
      let font = "enhanced font 'Times,"
      #else
      let font = "enhanced font ',"
      #endif
      switch self {
      case .svg(let path): return ["term":"svg size \(width),\(height)", "output": path.isEmpty ? "" : "'\(path)'"]
      case .pdf(let path): return ["term":"pdfcairo size 10,7.1 \(font)14'", "output": path.isEmpty ? "" : "'\(path)'"]
      case .png(let path): return ["term":"pngcairo size 1440, 900 \(font)12'", "output": path.isEmpty ? "" : "'\(path)'"]
      case .pngSmall(let path): return ["term":"pngcairo size 1024, 720 \(font)12'", "output": path.isEmpty ? "" : "'\(path)'"]
      case .pngLarge(let path): return ["term":"pngcairo size 1920, 1200 \(font)14'", "output": path.isEmpty ? "" : "'\(path)'"]
      }
    }
  }
  private var multiplot: Int = 0
  private let datablock: String
  private let defaultPlot: String
  private let SVG = ["border 31 lw 0.5 lc rgb 'black'", "grid ls 19"]
  private let PDF = ["border 31 lw 1 lc rgb 'black'", "grid ls 18"]
  private let PNG = ["object rectangle from graph 0,0 to graph 1,1 behind fillcolor rgb '#EBEBEB' fillstyle solid noborder"]
}
fileprivate let height = 800
fileprivate let width = 1255

private func separated<T: FloatingPoint>(_ xys: [[T]]) -> String { xys.map { xy in xy.map { "\($0)" }.joined(separator: " ") }.joined(separator: "\n") }
private func separated<T: FloatingPoint>(_ xys: [[T]], labels: [String]) -> String { 
  zip(xys, labels).map { xy, label in xy.map { "\($0) " }.joined() + label }.joined(separator: "\n") 
}
extension Array where Element == String { var concatenated: String { self.map { "set " + $0 + "\n" }.joined() } }
extension Dictionary where Key == String, Value == String { var concatenated: String { self.map { "set " + $0.key + " " + $0.value + "\n" }.joined() } }
