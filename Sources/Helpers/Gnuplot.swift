//  Copyright 2023 Daniel Müllenborn
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

/// A class for creating graphs using gnuplot.
public final class Gnuplot: CustomStringConvertible {
  public var base64PNG: String {
    try! callAsFunction(.pngSmall(""))!.base64EncodedString()
  }
#if canImport(Cocoa) && !targetEnvironment(macCatalyst)

  public var image: NSImage? {
    guard let data = try? callAsFunction(.pngSmall("")) else { return nil }
    return NSImage(data: data)
  }
#endif

  public init() { self.settings = defaultSettings() }

  public init(plotCommand: String) {
    self.plotCommands = [plotCommand]
    self.settings = defaultSettings()
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

  /// Generates an SVG representation of the graph.
  /// - Parameters:
  ///   - size: The size of the SVG image.
  /// - Returns: An SVG representation of the graph as a String.
  public func svg(size: (width: Int, height: Int)? = nil)-> String? {
    do {
      let term: Terminal
      if let size = size {
        term = Terminal.svg(width: size.width, height: size.height)
      } else {
        term = Terminal.svg()
      }
      guard let data = try callAsFunction(term),
      case .svg(let width, let height) = term,
      let start = data.firstIndex(where: {$0 == UInt8(ascii: ">")})?.advanced(by: 1)
      else { return nil }
      let namespace = #"xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">"#
      let tag = #"<svg width="\#(width+25)" height="\#(height)" viewBox="0 0 \#(width+25) \#(height)" "# + namespace
      return tag + String(decoding: data[start...], as: Unicode.UTF8.self)
    } catch {
      print(error)
      return nil
    }
  }

#if os(iOS)
    @discardableResult public func callAsFunction(_ terminal: Terminal) throws -> Data? {
      commands(terminal).data(using: .utf8)
    }
#else

    public static func process() -> Process {
#if os(Linux)
    if let process = Gnuplot.running { if process.isRunning { return process } }
    let gnuplot = Process()
    gnuplot.executableURL = .init(fileURLWithPath: "/usr/bin/gnuplot")
    gnuplot.arguments = ["--persist"]
    Gnuplot.running = gnuplot
#else
    let gnuplot = Process()
#endif
#if os(Windows)
    gnuplot.executableURL = .init(fileURLWithPath: "gnuplot.exe")
#elseif os(macOS)
    gnuplot.executableURL = .init(fileURLWithPath: "/opt/homebrew/bin/gnuplot")
#endif

    gnuplot.standardInput = Pipe()
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
  /// Calls the gnuplot process with the specified terminal settings.
  /// - Parameter terminal: The terminal settings to use.
  /// - Throws: An error if the process encounters an issue.
  /// - Returns: The data returned by the process.
  @discardableResult public func callAsFunction(_ terminal: Terminal) throws -> Data? {
    let gnuplot = Gnuplot.process()
    if !gnuplot.isRunning { try gnuplot.run() }
    let stdin = gnuplot.standardInput as! Pipe
    stdin.fileHandleForWriting.write(commands(terminal).data(using: .utf8)!)
    let stdout = gnuplot.standardOutput as! Pipe

#if os(Linux)
    let endOfData: Data
    if case .svg(_,_) = terminal {
      endOfData = "</svg>\n\n".data(using: .utf8)!
    } else if case .pdf(let path) = terminal, path.isEmpty {
      endOfData = Data([37, 37, 69, 79, 70, 10])  // %%EOF
    } else if case .pngSmall(let path) = terminal, path.isEmpty {
      endOfData = Data([73, 69, 78, 68, 174, 66, 96, 130])  // IEND
    } else {
      return nil
    }
    var data = Data()
    while data.suffix(endOfData.count) != endOfData {
      data.append(stdout.fileHandleForReading.availableData)
    }
    return data
#else
    try stdin.fileHandleForWriting.close()
    return try stdout.fileHandleForReading.readToEnd()
#endif
  }
#endif
  /// Generates a string containing the gnuplot commands to execute.
  /// - Parameter terminal: The terminal settings to use.
  /// - Returns: A string with the gnuplot commands.
  public func commands(_ terminal: Terminal? = nil) -> String {
    let config: String
    if let terminal = terminal {
      if case .svg = terminal {
        config = settings.merging(terminal.output) { old, _ in old }.concatenated + SVG.concatenated
      } else if case .pdf = terminal {
        config = settings.merging(terminal.output) { old, _ in old }.concatenated + PDF.concatenated
      } else {
        config =
        settings.merging(terminal.output) { old, _ in old }.concatenated + PNG.concatenated
        + SVG.concatenated
      }
    } else {
      config = settings.concatenated
    }

    let data = data.isEmpty ? "" 
      : ("\n$data <<EOD\n" + data.map(\.table).joined(separator: "\n\n\n") + "\n\nEOD\n\n")
    let plot = plotCommands.isEmpty ? defaultPlot : plotCommands
    if multiplot > 1 {
      let layout: (rows: Int, cols: Int)
      if multiplot == 9 {
        layout = (3, 3)
      } else {
        let z = multiplot.quotientAndRemainder(dividingBy: 2)
        let (x, y) = (z.quotient, (multiplot / z.quotient))
        layout = (min(x, y), max(x, y) + (x > 1 && z.remainder > 0 ? 1 : 0))
      }
      return data + config + "\n"
      + "set multiplot layout \(layout.rows),\(layout.cols) rowsfirst\n"
      + plot.first! + "\nreset session\nunset multiplot\n"
    }
    return data + config + "\n" + plot.joined(separator: "\n\n") + "\nreset session\n"
  }

  public var description: String { commands() }

  public var settings: [String: String]

  public var plotCommands: [String] = []

  /// Adds a plot command to the list of plot commands.
  ///
  /// - Parameters:
  ///   - multi: A flag indicating whether to create a multiplot layout.
  ///   - i: The index of the data series to plot (default is the last added series).
  ///   - x: The column index for the x-values (default is 1).
  ///   - y: The column index for the y-values (default is 2).
  ///   - style: The plotting style to use (default is `.linePoints`).
  /// - Returns: The updated Gnuplot instance.
  @discardableResult public func plot(
    multi: Bool, index i: Int? = nil, x: Int = 1, y: Int = 2, style: Style = .linePoints
  ) -> Self {
    let i = i ?? data.count - 1
    let (s, l) = style.raw
    multiplot += multi ? 1 : 0
    if styles.isEmpty { styles = Array(stride(from: 11, through: 14, by: 1)).shuffled() }
    let command =
    "$data i \(i) u \(x):\(y) \(s) w \(l) ls \(styles.removeLast()) title columnheader(1)"

    if let plot = plotCommands.first {
      plotCommands = [plot + (multi ? "\nplot " : ", ") + command]
    } else {
      plotCommands = ["plot " + command]
    }
    return self
  }

  /// Adds a plot command with labels to the list of plot commands.
  ///
  /// - Parameters:
  ///   - i: The index of the data series to plot (default is the last added series).
  ///   - x: The column index for the x-values (default is 1).
  ///   - y: The column index for the y-values (default is 2).
  ///   - rotate: The rotation angle for labels (default is 45 degrees).
  ///   - offset: The offset for label placement (default is "3,1.5").
  /// - Returns: The updated Gnuplot instance
  @discardableResult public func plotWithLabels(
    index i: Int? = nil, x: Int = 1, y: Int = 2, rotate: Int = 45, offset: String = "3,1.5"
  ) -> Self {
    let i = i ?? data.count - 1
    let command =
    "$data i \(i) u \(x):\(y):\"Label\" with labels tc ls 18 rotate by \(rotate) offset \(offset) notitle"
    if let plot = plotCommands.first {
      plotCommands = [plot + ", " + command]
    } else {
      plotCommands = ["plot " + command]
    }
    return self
  }

  /// Sets the title for the plot.
  ///
  /// - Parameter title: The title to set.
  /// - Returns: The updated Gnuplot instance.
  @discardableResult public func set(title: String) -> Self {
    settings["title"] = "'\(title)'"
    return self
  }

  /// Sets the x-axis label for the plot.
  ///
  /// - Parameter xlabel: The label for the x-axis.
  /// - Returns: The updated Gnuplot instance.
  @discardableResult public func set(xlabel: String) -> Self {
    settings["xlabel"] = "'\(xlabel)'"
    return self
  }

  /// Sets the y-axis label for the plot.
  ///
  /// - Parameter ylabel: The label for the y-axis.
  /// - Returns: The updated Gnuplot instance.
  @discardableResult public func set(ylabel: String) -> Self {
    settings["ylabel"] = "'\(ylabel)'"
    return self
  }

  @discardableResult public func set<T: BinaryFloatingPoint>(xrange x: ClosedRange<T>) -> Self {
    settings["xrange"] = "\(x.lowerBound):\(x.upperBound)"
    return self
  }

  @discardableResult public func set<T: BinaryFloatingPoint>(yrange y: ClosedRange<T>) -> Self {
    settings["yrange"] = "\(y.lowerBound):\(y.upperBound)"
    return self
  }

  @discardableResult public func set(xrange: DateInterval) -> Self {
    settings["xrange"] = "\(xrange.start.timeIntervalSince1970):\(xrange.end.timeIntervalSince1970)"
    settings["xdata"] = "time"
    settings["timefmt"] = "'%s'"
    settings["xtics rotate"] = ""

    if xrange.duration > 86400 {
      settings["xtics"] = "86400"
      settings["format x"] = "'%a'"
    } else {
      settings["xtics"] = "1800"
      settings["format x"] = "'%R'"
    }
    if xrange.duration > 86400 * 7 {
      settings["format x"] = "'%d.%m'"
    }
    return self
  }

  /// Adds multiple data series to the Gnuplot instance using x-values arrays.
  ///
  /// - Parameters:
  ///   - xs: Arrays of x-values for each data series.
  ///   - xylabels: Labels for the x and y axes (optional).
  ///   - titles: Titles for each data series.
  /// - Returns: The updated Gnuplot instance.
  @_disfavoredOverload @discardableResult
  public func data(xs: [Double]..., xylabels: [String] = [], titles: String...) -> Self { 
    data(xs: xs, xylabels: xylabels, titles: titles)
  }

  /// Adds multiple data series to the Gnuplot instance using arrays of x-values.
  ///
  /// - Parameters:
  ///   - xs: Arrays of x-values for each data series.
  ///   - xylabels: Labels for the x and y axes (optional).
  ///   - titles: Titles for each data series (optional).
  /// - Returns: The updated Gnuplot instance.
  @discardableResult
  public func data(xs: [[Double]], xylabels: [String] = [], titles: [String] = []) -> Self { 
    data.append(Arrays(columns: xs, names: titles, labels: xylabels))
    if plotCommands.isEmpty {
      _ = plot()
      defaultPlot = plotCommands
      plotCommands.removeAll()
    } else {
      
    }
    return self
  }

  /// Adds multiple data series to the Gnuplot instance using y-values arrays.
  ///
  /// - Parameters:
  ///   - ys: Arrays of y-values for each data series.
  ///   - xylabels: Labels for the x and y axes (optional).
  ///   - titles: Titles for each data series.
  /// - Returns: The updated Gnuplot instance.
  @_disfavoredOverload @discardableResult
  public func data(ys: [Double]..., xylabels: [String] = [], titles: String...) -> Self {
    data(ys: ys, xylabels: xylabels, titles: titles)
  }

  /// Adds multiple data series to the Gnuplot instance using arrays of y-values.
  ///
  /// - Parameters:
  ///   - ys: Arrays of y-values for each data series.
  ///   - xylabels: Labels for the x and y axes (optional).
  ///   - titles: Titles for each data series (optional).
  /// - Returns: The updated Gnuplot instance.
  @discardableResult
  public func data(ys: [[Double]], xylabels: [String] = [], titles: [String] = []) -> Self {
    data.append(Arrays(rows: ys, names: titles, labels: xylabels))
    if plotCommands.isEmpty {
      _ = plot()
      defaultPlot = plotCommands
      plotCommands.removeAll()
    }
    return self
  }

  /// Creates a plot with one or more data series using specified x and y columns and a style.
  ///
  /// - Parameters:
  ///   - i: The index of the data series to plot (optional).
  ///   - x: Columns containing x-values for the plot.
  ///   - y: Columns containing y-values for the plot.
  ///   - w: The plot style (default is `.linePoints`).
  /// - Returns: The updated Gnuplot instance.
  public func plot(i: Int? = nil, x: Int..., y: Int..., w: Style = .linePoints) -> Self {
    let i = i ?? data.count - 1
    let columnCount = data.last!.numbers.count
    let (s, l) = w.raw
    var plotCommands = [String]()
    if x.isEmpty, y.isEmpty {
      if data.last!.labeling.isEmpty {
        if columnCount == 2 {
          plotCommands.append("$data i \(i) u 1:2 \(s) w \(l) ls \(31) title columnheader(2)")
        } else if columnCount > 2 {
          for c in 2...columnCount+1 {
            plotCommands.append("$data i \(i) u 1:\(c) \(s) w \(l) ls \(c+29) title columnheader(\(c))")
          }
        } else {
          plotCommands.append("$data i \(i) u 0:1 \(s) w \(l) ls \(31) title columnheader(1)")
        }
      } else {
        if data.last!.numbers.count == 2 {
          plotCommands.append("$data i \(i) u 1:2:3 with labels tc ls 18 offset char 0,1 notitle")
        }
      }
    } else {
      if x.count == 1 {
        for c in y {
          plotCommands.append("$data i \(i) u \(x[0]):\(c) \(s) w \(l) ls \(c+29) title columnheader(\(c))")
        }
      } else if x.count == y.count {
        for (c1,c2) in zip(x,y) {
          plotCommands.append("$data i \(i) u \(c1):\(c2) \(s) w \(l) ls \(c1+29) title columnheader(\(c2))")
        }
      }
    }
    self.plotCommands.append("plot " + plotCommands.joined(separator: ", \\\n") + "\n")
    return self
  }
  
  /// Creates a dual-y axis plot with two data series using specified x and y columns and a style.
  ///
  /// - Parameters:
  ///   - i: The index of the data series to plot (optional).
  ///   - x: Columns containing x-values for the plot (default is `[0]`).
  ///   - y1: Columns containing y-values for the first y axis.
  ///   - y2: Columns containing y-values for the second y axis.
  ///   - w: The plot style (default is `.linePoints`).
  /// - Returns: The updated Gnuplot instance.
  public func plot2(i: Int? = nil, x: Int..., y1: Int..., y2: Int..., w: Style = .linePoints) -> Self {
    let i = i ?? data.count - 1
    let (s, l) = w.raw
    settings["ytics"] = "nomirror 1"
    settings["y2tics"] = "10"
    var plotCommands = [String]()
    let x = x.isEmpty ? [0] : x
    if x.count > 1 {
      for (c1,c2) in zip(x,y1) {
        plotCommands.append("$data i \(i) u \(c1):\(c2) \(s) axes x1y1 w \(l) ls \(30) title columnheader(\(c2))")
      }
      for (c1,c2) in zip(x,y2) {
        plotCommands.append("$data i \(i) u \(c1):\(c2) \(s) axes x1y2 w \(l) ls \(30) title columnheader(\(c2))")
      }
    } else {
      for c in y1 {
        plotCommands.append("$data i \(i) u \(x[0]):\(c) \(s) axes x1y1 w \(l) ls \(30) title columnheader(\(c))")
      }
      for c in y2 {
        plotCommands.append("$data i \(i) u \(x[0]):\(c) \(s) axes x1y2 w \(l) ls \(30) title columnheader(\(c))")
      }
    }
    self.plotCommands.append("plot " + plotCommands.joined(separator: ", \\\n") + "\n")
    return self
  }

  private(set) var data = [Arrays]()
  private var styles: [Int] = []
  private var multiplot: Int = 0
  private var defaultPlot = [String]()
  
  private let SVG = ["border 31 lw 0.5 lc rgb 'black'", "grid ls 19"]
  private let PDF = ["border 31 lw 1 lc rgb 'black'", "grid ls 18"]
  private let PNG = [
    "object rectangle from graph 0,0 to graph 1,1 behind fillcolor rgb '#EBEBEB' fillstyle solid noborder"
  ]
}

fileprivate func defaultSettings() -> [String: String] {
  var settings: [String: String] = [
    "style line 18": "lt 1 lw 1 dashtype 3 lc rgb 'black'",
    "style line 19": "lt 0 lw 0.5 lc rgb 'black'",
    "label": "textcolor rgb 'black'",
    "key": "above tc ls 18",
  ]

  let dark: [String] = ["1F78B4", "33A02C", "E31A1C", "FF7F00"]
  let light: [String] = ["A6CEE3", "B2DF8A", "FB9A99", "FDBF6F"]
  let pt = [4,6,8,10].shuffled()
  pt.indices.forEach { i in
    settings["style line \(i+11)"] = "lt 1 lw 1.5 pt \(pt[i]) ps 1.0 lc rgb '#\(dark[i])'"
    settings["style line \(i+21)"] = "lt 1 lw 1.5 pt \(pt[i]+1) ps 1.0 lc rgb '#\(light[i])'"
  }
  let mat = ["0072bd", "d95319", "edb120", "7e2f8e", "77ac30", "4dbeee", "a2142f"]
  mat.indices.forEach { i in
    settings["style line \(i+31)"] = "lt 1 lw 1.5 pt 7 ps 1.0 lc rgb '#\(mat[i])'"
  }
  return settings
}

extension Array where Element == String {
  var concatenated: String { self.map { "set " + $0 + "\n" }.joined() }
}
extension Dictionary where Key == String, Value == String {
  var concatenated: String { self.map { "set " + $0.key + " " + $0.value + "\n" }.joined() }
}
extension Collection where Element: FloatingPoint, Element: LosslessStringConvertible {
  var row: String { self.lazy.map(String.init).joined(separator: " ") + "\n" }
}

/// A structure for representing data arrays with columns, titles, and labels.
public struct Arrays {
  /// The name associated with the data array.
  var name: String = ""

  /// Initializes a `Arrays` instance with data organized by columns.
  ///
  /// - Parameters:
  ///   - series: A two-dimensional array of data columns.
  ///   - names: An optional array of header names for each column (default is auto-generated).
  ///   - labels: An optional array of labels for the data rows (default is empty).
  public init(columns series: [[Double]], names: [String] = [], labels: [String] = []) {
    let count = series.first!.count
    precondition(series.map(\.count).allSatisfy { $0 == count }, "Deviating count.")
    precondition(Set(names).count == names.count, "Headers not unique")
    let names = names.isEmpty ? series.indices.map {
      String(bytes: [UInt8(ascii: "A") + UInt8($0)], encoding: .ascii)!
    } : names
    precondition(series.count == names.count, "Deviating count.")
    self.titles = names
    self.numbers = series
    self.labeling = labels
  }

  /// Initializes a `Arrays` instance with data organized by rows.
  ///
  /// - Parameters:
  ///   - series: A two-dimensional array of data rows.
  ///   - names: An optional array of header names for each column (default is auto-generated).
  ///   - labels: An optional array of labels for the data rows (default is empty).
  public init(rows series: [[Double]], names: [String] = [], labels: [String] = []) {
    let count = series.first!.count
    let names = names.isEmpty ? series.indices.map {
      String(bytes: [UInt8(ascii: "A") + UInt8($0)], encoding: .ascii)!
    } : names
    precondition(series.map(\.count).allSatisfy { $0 == count }, "Deviating count.")
    self.titles = names
    self.numbers = series.transposed()
    self.labeling = labels
  }

  /// An array of header titles for each data column.
  var titles: [String]

  /// A two-dimensional array containing the data columns.
  var numbers: [[Double]]

  /// An array of labels associated with the data rows.
  var labeling: [String]

  /// The total number of columns, including data and labels.
  var count: Int { numbers.count + labeling.count}

  /// Generates a formatted table representation of the data array.
  ///
  /// - Returns: A string containing a formatted table of the data.
  var table: String {
    let transposedNumbers = numbers.transposed()

    let headerRow = (titles + ["Labels"]).joined(separator: " ")

    let dataRows = transposedNumbers.indices.map { i in
      let numberRow = transposedNumbers[i].map(\.description)
      if labeling.endIndex > i {
        return (numberRow + [labeling[i]]).joined(separator: " ")
      } else {
        return numberRow.joined(separator: " ")
      }
    }.joined(separator: "\n")

    return (name.isEmpty ? "" : "\(name)\n") + headerRow + "\n" + dataRows
  }
}

extension Gnuplot {

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
    #if os(Windows)
    case svg(width: Int = 1255, height: Int = 720)
    #elseif os(Linux)
    case svg(width: Int = 1000, height: Int = 750)
    #else
    case svg(width: Int = 1255, height: Int = 800)
    #endif
    case pdf(_ toFile: String)
    case png(_ toFile: String)
    case pngSmall(_ toFile: String)
    case pngLarge(_ toFile: String)
    var output: [String: String] {
      var settings = [String: String]()
#if os(Linux)
      let f = "enhanced font 'Times,"
#else
      let f = "enhanced font ',"
#endif
      switch self {
      case .svg(let w, let h):
        return ["term": "svg size \(w),\(h)", "output": ""]
      case .pdf(let path):
        settings["term"] = "pdfcairo size 10,7.1 \(f)14'"
        settings["output"] = path.isEmpty ? "" : "'\(path)'"
      case .png(let path):
        settings["term"] = "pngcairo size 1440, 900 \(f)12'"
        settings["output"] = path.isEmpty ? "" : "'\(path)'"
      case .pngSmall(let path):
        settings["term"] = "pngcairo size 1024, 720 \(f)12'"
        settings["output"] = path.isEmpty ? "" : "'\(path)'"
      case .pngLarge(let path):
        settings["term"] = "pngcairo size 1920, 1200 \(f)14'"
        settings["output"] = path.isEmpty ? "" : "'\(path)'"
      }
      return settings
    }
  }

  public func data<Scalar: BinaryFloatingPoint, Vector: Collection, Tensor: Collection, Series: Collection>
  (y1s: Series, y2s: Series, titles: [String] = [], range: DateInterval)
  where Tensor.Element == Vector, Vector.Element == Scalar, Series.Element == Tensor, Scalar: LosslessStringConvertible {
    for y1 in y1s {
      data.append(Arrays(columns: y1.map {$0.map{Double($0)}}, names: Array(titles[..<y1s.count])))
    }
    for y2 in y2s {
      data.append(Arrays(columns: y2.map {$0.map{Double($0)}}, names: Array(titles[y1s.count...])))
    }
    var setting: [String: String] = [
      "xdata": "time", "timefmt": "'%s'",
      "xrange": "[\(range.start.timeIntervalSince1970):\(range.end.timeIntervalSince1970)]"
    ]
    if !y2s.isEmpty {
      setting["ytics"] = "nomirror"
      setting["y2tics"] = ""
    }

    if range.duration > 86400 {
      setting["xtics"] = "86400"
      setting["format x"] = "'%j'"
    } else {
      setting["xtics"] = "1800"
      setting["format x"] = "'%R'"
      setting["xtics rotate"] = ""
    }

    self.settings = self.settings.merging(setting) { _, new in new }
    var plotCommands = "plot "
    plotCommands += y1s.enumerated().map { i, ys -> String in
      "$data i \(i) u ($0*\(range.duration / Double(ys.count))+\(range.start.timeIntervalSince1970)):\(1) axes x1y1 w l ls \(i+11) title columnheader(1)"
    }.joined(separator: ", \\\n")
    if !y2s.isEmpty {
      plotCommands += ", \\\n" + y2s.enumerated().map { i, ys -> String in
        "$data i \(i + y1s.count) u ($0*\(range.duration / Double(ys.count))+\(range.start.timeIntervalSince1970)):\(1) axes x1y2 w l ls \(i+21) title columnheader(1)"
      }.joined(separator: ", \\\n")
    }
    self.defaultPlot = [plotCommands]
  }

  public func data<Scalar: BinaryFloatingPoint, Vector: RandomAccessCollection, Tensor: RandomAccessCollection, Series: Collection>
  (y1s: Series, y2s: Series) where Tensor.Element == Vector, Vector.Element == Scalar, Series.Element == Tensor, Scalar: LosslessStringConvertible {
    for y1 in y1s {
      data.append(Arrays(columns: y1.map {$0.map{Double($0)}}))
    }
    for y2 in y2s {
      data.append(Arrays(columns: y2.map {$0.map{Double($0)}}))
    }
    let setting = [
      "key": "off", "xdata": "time", "timefmt": "'%s'", "format x": "'%k'",
      "xtics": "21600 ", "yrange": "0:1", "ytics": "0.25", "term": "pdfcairo size 7.1, 10",
    ]
    self.settings = self.settings.merging(setting) { _, new in new }
    let y = y1s.count
    self.defaultPlot = [y1s.enumerated().map { i, y1 -> String in
      "\nset multiplot layout 8,4 rowsfirst\n"
      + (1...y1.count).map { c in
        "plot $data i \(i) u ($0*300):\(c) axes x1y1 w l ls 31, $data i \(i+y) u ($0*300):\(c) axes x1y2 w l ls 32"
      }.joined(separator: "\n") + "\nunset multiplot"
    }.joined(separator: "\n")]
  }
}
