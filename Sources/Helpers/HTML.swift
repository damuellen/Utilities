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
#if os(Windows)
import WinSDK
#endif

/// A representation of an HTML document.
///
/// Call the `render()` method to turn it into a string.
public struct HTML {
  var data: Data { raw.data(using: .utf8)! }
  /// Creates an html string from the document
  public func render() -> String { return raw }
  /// Create a pdf file from the document.
  public func pdf(toFile name: String) throws {
    let html = URL.temporaryFile().appendingPathExtension("html")
    try data.write(to: html)
    let path = html.path
    let wkhtmltopdf = Process()
    wkhtmltopdf.arguments = [
      "--quiet", "--print-media-type", "--disable-smart-shrinking",
      "-L", "0", "-R", "0", "-T", "0", "-B", "0",
      "-O", "Landscape", "--dpi", "600", path, name
    ]
#if os(Windows)
    wkhtmltopdf.executableURL = .init(fileURLWithPath: "C:/bin/wkhtmltopdf.exe")
#else
    wkhtmltopdf.executableURL = .init(fileURLWithPath: "/usr/local/bin/wkhtmltopdf")
#endif
    try wkhtmltopdf.run()
    wkhtmltopdf.waitUntilExit()
    try html.removeItem()
  }
  /// Creates an HTML document with the given body.
  public init(body: String? = nil, refresh: Int = 0) {
    self.bodyContent = body ?? (Bool.random() ? HTML.lazySVG : HTML.sleepSVG)
    self.meta = "<meta charset=\"utf-8\">\n" + ((refresh > 0) ? """
    <meta http-equiv=\"refresh\" content=\"\(refresh)\">
    <style type="text/css">
    @keyframes moving { 
        0%   { opacity:0; transform: translate3d(-100%, 0, 0); }
        4%   { opacity:1; transform: none; }
        96%  { opacity:1; transform: none; }
        100% { opacity:0; transform: translate3d(100%, 0, 0); }
    }
    @keyframes fade { 
        0%   { opacity:0; transform: translate3d(0, -100%, 0); }
        15%  { opacity:1; transform: none; }
        80%  { opacity:1; }
        95%  { opacity:0; }
        100% { opacity:0; }
    }
    svg {
        opacity:0;  
        animation: moving \(refresh)s;
    }
    #Layer_1 {
        opacity:0;  
        animation: fade \(refresh)s;
    }
    </style>
    """ : "")
  }
  
  public mutating func add(body: String) {
    bodyContent.append(body)
  } 
  /// Optional json content to be rendered.
  public var json: String? = nil

  private var bodyContent: String

  private let type = "<!DOCTYPE html>\n"
  private let meta: String
  
  private static let lazySVG = """
    <svg id=Layer_1 style="enable-background:new 0 0 511.995 511.995"version=1.1 viewBox="0 0 511.995 511.995"x=0px xml:space=preserve xmlns=http://www.w3.org/2000/svg xmlns:xlink=http://www.w3.org/1999/xlink y=0px><g><g><path d="M496.291,252.216H366.089c0.646-1.679,1.113-3.454,1.323-5.325c1.321-11.787-7.163-22.412-18.95-23.732l-99.572-11.156
      c-6.069-0.682-12.142,1.257-16.697,5.325l-33.62,30.03l-38.949-86.367l35.459-79.849c4.996-11.251-4.001-23.746-16.266-22.568
    l-64.362,6.208c7.086,5.32,12.809,12.509,16.393,21.073c1.288,3.076,2.258,6.231,2.92,9.426l20.677-1.994l-20.945,47.165
    l-57.423,25.309l13.15,10.09l-49.403-18.357l8.992-15.122c-4.993-4.761-9.062-10.578-11.844-17.222
    c-2.592-6.192-3.91-12.7-3.966-19.217L2.266,157.63c-5.13,8.63-1.192,19.826,8.234,23.328l82.074,30.498l-17.434-3.562
    l43.968,105.046h-18.97L69.303,206.7l-33.609-6.867l38.462,132.518c1.883,6.488,7.825,10.951,14.58,10.951l51.688,0.031
    l-0.006,62.139l-36.063,29.44c-4.481,3.658-5.147,10.254-1.49,14.735c3.657,4.481,10.254,5.148,14.735,1.49l22.818-18.627v10.514
    c0,5.784,4.688,10.472,10.472,10.472c5.784,0,10.472-4.688,10.472-10.472V432.51l22.818,18.627
    c4.484,3.659,11.08,2.987,14.735-1.49c3.658-4.481,2.991-11.077-1.49-14.735l-36.063-29.439v-62.17h53.134
    c8.384,0,15.181-6.797,15.181-15.181s-6.797-15.181-15.181-15.181h-24.872l64.022-57.187l18.075,2.025
    c-2.321,2.738-3.727,6.276-3.727,10.146c0,8.676,7.033,15.708,15.708,15.708h2.094v159.394c0,5.783,4.688,10.472,10.472,10.472
    c5.784,0,10.472-4.688,10.472-10.472V283.632h167.556v159.394c0,5.783,4.688,10.472,10.472,10.472s10.472-4.688,10.472-10.472
    V283.632h1.047c8.676,0,15.708-7.033,15.708-15.708C511.995,259.248,504.966,252.216,496.291,252.216z"/></g></g><g><g><path d="M118.289,91.109c-7.951-18.998-29.789-27.934-48.77-19.99c-18.988,7.948-27.937,29.782-19.989,48.77
      c7.951,18.996,29.789,27.935,48.77,19.99C117.287,131.932,126.237,110.097,118.289,91.109z"/></g></g><g><g><path d="M471.157,219.864h-72.112c-5.205,0-9.425,4.22-9.425,9.425s4.22,9.425,9.425,9.425h72.112c5.205,0,9.425-4.22,9.425-9.425
      S476.362,219.864,471.157,219.864z"/></g></g><g><g><path d="M471.157,189.636h-72.112c-5.205,0-9.425,4.22-9.425,9.425c0,5.205,4.22,9.425,9.425,9.425h72.112
      c5.205,0,9.425-4.22,9.425-9.425C480.582,193.855,476.362,189.636,471.157,189.636z"/></g></g><g><g><path d="M471.157,159.408h-72.112c-5.205,0-9.425,4.22-9.425,9.425c0,5.205,4.22,9.425,9.425,9.425h72.112
      c5.205,0,9.425-4.22,9.425-9.425C480.582,163.627,476.362,159.408,471.157,159.408z"/></g></g><g><g><path d="M471.157,129.18h-72.112c-5.205,0-9.425,4.22-9.425,9.425c0,5.205,4.22,9.425,9.425,9.425h72.112
      c5.205,0,9.425-4.22,9.425-9.425C480.582,133.4,476.362,129.18,471.157,129.18z"/></g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g></svg>
    """
  
  private static let sleepSVG = """
    <svg id=Layer_1 style="enable-background:new 0 0 512 512"version=1.1 viewBox="0 0 512 512"x=0px xml:space=preserve xmlns=http://www.w3.org/2000/svg xmlns:xlink=http://www.w3.org/1999/xlink y=0px><g><g><circle cx=287.146 cy=157.427 r=44.386 /></g></g><g><g><path d="M495.354,261.85c-8.193,0-154.733,0-162.055,0c3.7-3.747,5.943-8.923,5.806-14.603
    c-0.265-11.103-9.508-19.918-20.585-19.622l-69.543,1.665l-38.271-54.704l29.287,24.491c-1.544-2.3-30.916-38.075-30.004-36.96
    c-6.592-8.063-16.494-12.69-26.909-12.571c-10.415,0.119-20.208,4.971-26.615,13.183L78.092,263.207
    c-8.148,10.456-11.39,25.034-6.617,37.963c2.83,7.664,10.743,13.744,19.061,16.148c7.889,3.882,10.432,2.532,36.608,8.815H53.671
    L32.05,155.401c-1.115-8.814-9.165-15.058-17.981-13.939c-8.815,1.116-15.055,9.166-13.94,17.981l23.402,184.799
    c1.018,8.039,7.857,14.067,15.96,14.067h58.097v65.881l-38.216,31.197c-4.747,3.876-5.456,10.867-1.579,15.614
    s10.867,5.455,15.614,1.579l24.18-19.739v11.143c0,6.129,4.968,11.097,11.097,11.097s11.097-4.968,11.097-11.097v-11.143
    l24.18,19.739c4.751,3.877,11.74,3.167,15.614-1.579c3.876-4.747,3.168-11.739-1.579-15.614l-38.216-31.197v-65.881h52.977
    c9.224,0,16.787-7.819,16.023-17.384l4.59,1.102l-28.156,102.527c-3.53,12.852,4.027,26.131,16.879,29.661
    c12.855,3.53,26.132-4.031,29.661-16.879l34.758-126.565c3.608-13.136-4.38-26.674-17.639-29.857l-44.616-10.707l20.355-18.184
    l-26.864-74.382l44.452,63.539c3.769,5.387,9.923,8.582,16.476,8.582c0.161,0,0.322-0.002,0.483-0.006l17.015-0.407
    c-1.732,2.626-2.747,5.767-2.747,9.149c0,9.18,7.443,16.646,16.646,16.646h2.219v168.842c0,6.129,4.968,11.097,11.097,11.097
    c6.129,0,11.097-4.968,11.097-11.097V295.142h177.559v168.842c0,6.129,4.968,11.097,11.097,11.097
    c6.129,0,11.097-4.968,11.097-11.097V295.142h1.11c9.195,0,16.648-7.453,16.648-16.646S504.547,261.85,495.354,261.85z"/></g></g><g><g><path d="M498.466,160.972c-5.375-2.944-12.12-0.975-15.065,4.4l-33.463,61.078h-60.176c-6.127,0-11.096,4.968-11.096,11.097
    c0,6.129,4.968,11.097,11.097,11.097h66.749c4.054,0,7.785-2.211,9.732-5.765l36.622-66.843
    C505.811,170.663,503.84,163.918,498.466,160.972z"/></g></g><g><g><path d="M395.091,122.819h-20.414l21.164-37.449c0.826-1.501,1.276-2.926,1.276-4.127c0-1.801-1.126-3.077-3.377-3.077h-28.969
    c-2.476,0-3.528,2.627-3.528,5.104c0,2.702,1.276,5.104,3.528,5.104h17.411l-21.164,37.449c-0.826,1.426-1.276,2.927-1.276,4.128
    c0,1.801,0.977,3.076,3.378,3.076h31.971c2.252,0,3.528-2.702,3.528-5.104S397.343,122.819,395.091,122.819z"/></g></g><g><g><path d="M438.629,84.181h-14.062l14.579-25.797c0.569-1.034,0.879-2.016,0.879-2.843c0-1.241-0.776-2.12-2.326-2.12h-19.955
    c-1.707,0-2.429,1.809-2.429,3.516c0,1.861,0.879,3.515,2.429,3.515h11.994l-14.579,25.797c-0.569,0.982-0.879,2.016-0.879,2.843
    c0,1.241,0.672,2.12,2.326,2.12h22.023c1.55,0,2.429-1.861,2.429-3.516C441.058,86.041,440.179,84.181,438.629,84.181z"/></g></g><g><g><path d="M467.323,53.721h-7.683l7.965-14.094c0.311-0.565,0.481-1.102,0.481-1.554c0-0.678-0.423-1.157-1.271-1.157h-10.902
    c-0.932,0-1.327,0.989-1.327,1.92c0,1.018,0.481,1.921,1.327,1.921h6.552L454.5,54.851c-0.311,0.536-0.481,1.102-0.481,1.554
    c0,0.677,0.367,1.157,1.272,1.157h12.032c0.848,0,1.327-1.016,1.327-1.92C468.65,54.739,468.17,53.721,467.323,53.721z"/></g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g></svg>
    """
  
  private let style = """
    <style media="print">
      svg { font-family: sans-serif; font-size: 16px;}
      button { display: none; }
    </style>
    <style media="screen">
      svg {
        margin-top: 1%;
        margin-left: 1%;
        margin-right: auto;
        padding-bottom: 2vh;
        height: 95vh;
        width: 98%;
        font-family: sans-serif;
        font-size: 16px;
      }
      tspan { font-family: sans-serif;}
      body { background-color: rgb(247,247,247); overflow: hidden; }
      @media (prefers-color-scheme: dark) {
        svg { filter: drop-shadow(3px 3px 3px rgb(255, 255, 255)); }
        body {
          background-color: rgb(20,20,20);
          background-image: radial-gradient(circle, rgb(50,50,50), rgb(20,20,20));
          filter: invert(1);
        }
      }
    </style>
    """

  private let script = """
    <link href="https://cdnjs.cloudflare.com/ajax/libs/jsoneditor/9.4.1/jsoneditor.min.css" rel="stylesheet" type="text/css">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jsoneditor/9.4.1/jsoneditor.min.js"></script>
    <div id="jsoneditor" style="width: 50%; height: 95vh; margin-left: 22%; padding: 2vh; margin-top: 5vh;"></div>
    <script>new JSONEditor(document.getElementById("jsoneditor"), {},
    """

  private var raw: String {
    let head = "<html lang=\"en\"><head>" + meta + style + "</head>\n<body>\n"
    let tail = "</body>\n</html>\n"
    let full = "<button onclick=\"window.stop(); document.documentElement.requestFullscreen();\" style=\"position: fixed; left: 8px; top: 8px; z-index: 1;\">Fullscreen</button>\n"
    let cancel = "<a href=\"/cancel\"><button style=\"position: fixed; right: 8px; top: 8px; z-index: 1;\">Cancel</button></a>\n"
    if let json = json {
      return type + head + cancel + full + bodyContent + script + json + ")</script>" + tail
    }
    return type + head + cancel + full + bodyContent + tail
  }
}
