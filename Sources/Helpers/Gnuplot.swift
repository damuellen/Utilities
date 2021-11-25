 #if canImport(Cocoa)
  public var image: NSImage? { 
    guard let data = try? self(.pngSmall(path: "")) else { return nil }
    return NSImage(data: data) 
  }
  #endif
  public var svg: String? {
    var last = UInt8(0)
    do { 
      guard let data = try self(.svg(path: "")) else { return nil }
      let svg = data.drop(while: {
        if last == UInt8(ascii: ">") { return false }
        last = $0
        return true
      })
      return String(decoding: svg, as: Unicode.UTF8.self)
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
    gnuplot.standardError = nil
    return gnuplot
  }
  /// Execute the plot commands.
  @discardableResult public func callAsFunction(_ terminal: Terminal) throws -> Data? {
    let process = Gnuplot.process()
    try process.run()
    let stdin = process.standardInput as! Pipe
    stdin.fileHandleForWriting.write(commands(terminal).data(using: .utf8)!)
    try stdin.fileHandleForWriting.close()
    let stdout = process.standardOutput as! Pipe
    return try stdout.fileHandleForReading.readToEnd()
  }
  public func commands(_ terminal: Terminal? = nil) -> String {
    let config: String
    if let terminal = terminal {  
      if case .svg = terminal {
        config = settings.merging(terminal.output){old,_ in old}.concatenated + SVG.concatenated } 
      else if case .pdf = terminal {
        config = settings.merging(terminal.output){_,new in new}.concatenated + PDF.concatenated }
      else { 
        config = settings.merging(terminal.output){_,new in new}.concatenated + PNG.concatenated + SVG.concatenated
      }
    } else {
      config = settings.concatenated + PNG.concatenated
    }
    let plot = userPlot ?? defaultPlot
    return datablock + config 
      + (multiplot > 0 ? "set multiplot layout 1,\(multiplot)\n" : "")
      + plot + (multiplot > 0 ? "unset multiplot\n" : "\n")
  }
