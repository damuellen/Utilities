//
//  Copyright 2023 Daniel Müllenborn
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation
import Helpers

#if os(Windows)
  import WinSDK
#endif

/// A representation of an HTML document.
///
/// Call the `render()` method to turn it into a string.
public struct HTML: CustomStringConvertible {
  var data: Data { raw.data(using: .utf8)! }
  /// Creates an html string from the document
  public var description: String { return raw }
  /// Create a pdf file from the document.
  public func pdf(toFile name: String) throws {
    #if os(Windows) || os(Linux)
      let html = URL.temporaryFile().appendingPathExtension("html")
      try data.write(to: html)
      let path = html.path
      let wkhtmltopdf = Process()
      wkhtmltopdf.arguments = [
        "--quiet", "--print-media-type", "--disable-smart-shrinking",
        "-L", "0", "-R", "0", "-T", "0", "-B", "0",
        "-O", "Landscape", "--dpi", "600", path, name,
      ]
      #if os(Windows)
        let localappdata = ProcessInfo.processInfo.environment["LOCALAPPDATA"]!
        wkhtmltopdf.executableURL = .init(fileURLWithPath: localappdata + "/Microsoft/WindowsApps/wkhtmltopdf.exe")
      #else
        wkhtmltopdf.executableURL = "/usr/local/bin/wkhtmltopdf"
      #endif
      try wkhtmltopdf.run()
      wkhtmltopdf.waitUntilExit()
      try html.removeItem()
    #endif
  }

  /// Creates an HTML document with the given body.
  public init(body: String? = nil, refresh: Int = 0) {
    let cancel: String = """
      <a href="/cancel">
      <button style="position: fixed; right: 8px; top: 8px; z-index: 1;">Cancel</button>
      </a>
      """
    if let content = body {
      self.bodyContent = content + (refresh > 0 ? cancel : "")
    } else {
      self.bodyContent = [lazySVG, coffeeSVG, sleepSVG].randomElement()!
    }

    let cs = "<meta charset=\"utf-8\">\n"
    if refresh > 0 {
      self.meta = """
        \(cs)<meta http-equiv=\"refresh\" content=\"\(refresh)\">
        <style type="text/css">
           @keyframes move {
            0%   { opacity:0; transform: translateY(-100%); }
            15%  { opacity:1; transform: none; }
            80%  { opacity:1; }
            95%  { opacity:0; }
            100% { opacity:0; }
        }
        #Layer_1 {
            opacity:0;
            animation: move \(refresh)s;
        }
        </style>
        """
    } else {
      self.meta = cs
    }
  }

  public mutating func add(body: String) {
    bodyContent.append(body)
  }
  /// Optional json content to be rendered.
  public var json: String? = nil

  private var bodyContent: String

  private let type = "<!DOCTYPE html>\n"
  private let meta: String

  private let lazySVG: String = #"<svg id=Layer_1 style="enable-background:new 0 0 511.995 511.995" version=1.1 viewBox="0 0 511.995 511.995" x=0px y=0px xml:space=preserve xmlns=http://www.w3.org/2000/svg xmlns:xlink=http://www.w3.org/1999/xlink><g><g><path d="M496.291,252.216H366.089c0.646-1.679,1.113-3.454,1.323-5.325c1.321-11.787-7.163-22.412-18.95-23.732l-99.572-11.156  c-6.069-0.682-12.142,1.257-16.697,5.325l-33.62,30.03l-38.949-86.367l35.459-79.849c4.996-11.251-4.001-23.746-16.266-22.568l-64.362,6.208c7.086,5.32,12.809,12.509,16.393,21.073c1.288,3.076,2.258,6.231,2.92,9.426l20.677-1.994l-20.945,47.165l-57.423,25.309l13.15,10.09l-49.403-18.357l8.992-15.122c-4.993-4.761-9.062-10.578-11.844-17.222c-2.592-6.192-3.91-12.7-3.966-19.217L2.266,157.63c-5.13,8.63-1.192,19.826,8.234,23.328l82.074,30.498l-17.434-3.562l43.968,105.046h-18.97L69.303,206.7l-33.609-6.867l38.462,132.518c1.883,6.488,7.825,10.951,14.58,10.951l51.688,0.031l-0.006,62.139l-36.063,29.44c-4.481,3.658-5.147,10.254-1.49,14.735c3.657,4.481,10.254,5.148,14.735,1.49l22.818-18.627v10.514c0,5.784,4.688,10.472,10.472,10.472c5.784,0,10.472-4.688,10.472-10.472V432.51l22.818,18.627c4.484,3.659,11.08,2.987,14.735-1.49c3.658-4.481,2.991-11.077-1.49-14.735l-36.063-29.439v-62.17h53.134c8.384,0,15.181-6.797,15.181-15.181s-6.797-15.181-15.181-15.181h-24.872l64.022-57.187l18.075,2.025c-2.321,2.738-3.727,6.276-3.727,10.146c0,8.676,7.033,15.708,15.708,15.708h2.094v159.394c0,5.783,4.688,10.472,10.472,10.472c5.784,0,10.472-4.688,10.472-10.472V283.632h167.556v159.394c0,5.783,4.688,10.472,10.472,10.472s10.472-4.688,10.472-10.472V283.632h1.047c8.676,0,15.708-7.033,15.708-15.708C511.995,259.248,504.966,252.216,496.291,252.216z"/></g></g><g><g><path d="M118.289,91.109c-7.951-18.998-29.789-27.934-48.77-19.99c-18.988,7.948-27.937,29.782-19.989,48.77  c7.951,18.996,29.789,27.935,48.77,19.99C117.287,131.932,126.237,110.097,118.289,91.109z"/></g></g><g><g><path d="M471.157,219.864h-72.112c-5.205,0-9.425,4.22-9.425,9.425s4.22,9.425,9.425,9.425h72.112c5.205,0,9.425-4.22,9.425-9.425  S476.362,219.864,471.157,219.864z"/></g></g><g><g><path d="M471.157,189.636h-72.112c-5.205,0-9.425,4.22-9.425,9.425c0,5.205,4.22,9.425,9.425,9.425h72.112  c5.205,0,9.425-4.22,9.425-9.425C480.582,193.855,476.362,189.636,471.157,189.636z"/></g></g><g><g><path d="M471.157,159.408h-72.112c-5.205,0-9.425,4.22-9.425,9.425c0,5.205,4.22,9.425,9.425,9.425h72.112  c5.205,0,9.425-4.22,9.425-9.425C480.582,163.627,476.362,159.408,471.157,159.408z"/></g></g><g><g><path d="M471.157,129.18h-72.112c-5.205,0-9.425,4.22-9.425,9.425c0,5.205,4.22,9.425,9.425,9.425h72.112  c5.205,0,9.425-4.22,9.425-9.425C480.582,133.4,476.362,129.18,471.157,129.18z"/></g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g></svg>"#
  private let sleepSVG: String = #"<svg id=Layer_1 style="enable-background:new 0 0 512 512" version=1.1 viewBox="0 0 512 512" x=0px y=0px xml:space=preserve xmlns=http://www.w3.org/2000/svg xmlns:xlink=http://www.w3.org/1999/xlink><g><g><circle cx=287.146 cy=157.427 r=44.386 /></g></g><g><g><path d="M495.354,261.85c-8.193,0-154.733,0-162.055,0c3.7-3.747,5.943-8.923,5.806-14.603c-0.265-11.103-9.508-19.918-20.585-19.622l-69.543,1.665l-38.271-54.704l29.287,24.491c-1.544-2.3-30.916-38.075-30.004-36.96c-6.592-8.063-16.494-12.69-26.909-12.571c-10.415,0.119-20.208,4.971-26.615,13.183L78.092,263.207c-8.148,10.456-11.39,25.034-6.617,37.963c2.83,7.664,10.743,13.744,19.061,16.148c7.889,3.882,10.432,2.532,36.608,8.815H53.671L32.05,155.401c-1.115-8.814-9.165-15.058-17.981-13.939c-8.815,1.116-15.055,9.166-13.94,17.981l23.402,184.799c1.018,8.039,7.857,14.067,15.96,14.067h58.097v65.881l-38.216,31.197c-4.747,3.876-5.456,10.867-1.579,15.614s10.867,5.455,15.614,1.579l24.18-19.739v11.143c0,6.129,4.968,11.097,11.097,11.097s11.097-4.968,11.097-11.097v-11.143l24.18,19.739c4.751,3.877,11.74,3.167,15.614-1.579c3.876-4.747,3.168-11.739-1.579-15.614l-38.216-31.197v-65.881h52.977c9.224,0,16.787-7.819,16.023-17.384l4.59,1.102l-28.156,102.527c-3.53,12.852,4.027,26.131,16.879,29.661c12.855,3.53,26.132-4.031,29.661-16.879l34.758-126.565c3.608-13.136-4.38-26.674-17.639-29.857l-44.616-10.707l20.355-18.184l-26.864-74.382l44.452,63.539c3.769,5.387,9.923,8.582,16.476,8.582c0.161,0,0.322-0.002,0.483-0.006l17.015-0.407c-1.732,2.626-2.747,5.767-2.747,9.149c0,9.18,7.443,16.646,16.646,16.646h2.219v168.842c0,6.129,4.968,11.097,11.097,11.097c6.129,0,11.097-4.968,11.097-11.097V295.142h177.559v168.842c0,6.129,4.968,11.097,11.097,11.097c6.129,0,11.097-4.968,11.097-11.097V295.142h1.11c9.195,0,16.648-7.453,16.648-16.646S504.547,261.85,495.354,261.85z"/></g></g><g><g><path d="M498.466,160.972c-5.375-2.944-12.12-0.975-15.065,4.4l-33.463,61.078h-60.176c-6.127,0-11.096,4.968-11.096,11.097c0,6.129,4.968,11.097,11.097,11.097h66.749c4.054,0,7.785-2.211,9.732-5.765l36.622-66.843C505.811,170.663,503.84,163.918,498.466,160.972z"/></g></g><g><g><path d="M395.091,122.819h-20.414l21.164-37.449c0.826-1.501,1.276-2.926,1.276-4.127c0-1.801-1.126-3.077-3.377-3.077h-28.969c-2.476,0-3.528,2.627-3.528,5.104c0,2.702,1.276,5.104,3.528,5.104h17.411l-21.164,37.449c-0.826,1.426-1.276,2.927-1.276,4.128c0,1.801,0.977,3.076,3.378,3.076h31.971c2.252,0,3.528-2.702,3.528-5.104S397.343,122.819,395.091,122.819z"/></g></g><g><g><path d="M438.629,84.181h-14.062l14.579-25.797c0.569-1.034,0.879-2.016,0.879-2.843c0-1.241-0.776-2.12-2.326-2.12h-19.955c-1.707,0-2.429,1.809-2.429,3.516c0,1.861,0.879,3.515,2.429,3.515h11.994l-14.579,25.797c-0.569,0.982-0.879,2.016-0.879,2.843c0,1.241,0.672,2.12,2.326,2.12h22.023c1.55,0,2.429-1.861,2.429-3.516C441.058,86.041,440.179,84.181,438.629,84.181z"/></g></g><g><g><path d="M467.323,53.721h-7.683l7.965-14.094c0.311-0.565,0.481-1.102,0.481-1.554c0-0.678-0.423-1.157-1.271-1.157h-10.902c-0.932,0-1.327,0.989-1.327,1.92c0,1.018,0.481,1.921,1.327,1.921h6.552L454.5,54.851c-0.311,0.536-0.481,1.102-0.481,1.554c0,0.677,0.367,1.157,1.272,1.157h12.032c0.848,0,1.327-1.016,1.327-1.92C468.65,54.739,468.17,53.721,467.323,53.721z"/></g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g></svg>"#
  private let coffeeSVG: String = #"<svg id=Layer_1 style="enable-background:new 0 0 512 512" version=1.1 viewBox="0 0 512 512" x=0px y=0px xml:space=preserve xmlns=http://www.w3.org/2000/svg xmlns:xlink=http://www.w3.org/1999/xlink><g><g><path d="M387.494,160.117c-5.373-2.946-12.119-0.977-15.065,4.4l-33.463,61.077h-38.141c2.123-3.699,3.109-8.088,2.503-12.642c-1.467-11.009-11.585-18.745-22.59-17.276l-52.064,6.938c-11.069,32.174-11.355,36.036-18.903,43.092l58.002-7.729c0.638,5.522,5.323,9.811,11.018,9.811h66.75c4.054,0,7.785-2.209,9.732-5.765l36.622-66.842C394.839,169.805,392.868,163.061,387.494,160.117z"/></g></g><g><g><path d="M240.013,71.54l-2.627-0.5c1.865-9.797-4.552-19.235-14.349-21.101c-9.856-1.873-19.251,4.633-21.1,14.349l-2.627-0.5c-2.431-0.463-4.777,1.133-5.241,3.564l-4.863,25.534c10.15-6.362,22.977-8.256,35.186-4.057c5.852,2.013,10.949,5.224,15.128,9.253l4.057-21.3C244.041,74.35,242.445,72.004,240.013,71.54z M225.396,68.756l-11.466-2.184c0.599-3.149,3.642-5.251,6.825-4.64C223.924,62.536,225.999,65.588,225.396,68.756z"/></g></g><g><g><path d="M254.216,445.92L238.304,321.4c-1.251-9.795-8.344-17.839-17.905-20.307l-50.254-12.974l2.606-36.711l-67.559-55.337l69.275,31.788c10.784,4.952,23.53-0.481,27.403-11.736l28.182-81.923c3.612-10.503-1.972-21.944-12.475-25.557c-10.503-3.61-21.945,1.972-25.557,12.475l-20.96,60.927l-49.093-22.526l32.841,5.365l4.551-12.902c0,0-5.182-0.301-60.458-4.224c-17.424-1.236-32.239,12.651-32.106,30.137l1.112,146.272H53.672L32.05,153.434c-1.115-8.815-9.162-15.055-17.981-13.939c-8.815,1.116-15.055,9.167-13.94,17.981l23.403,184.798c1.018,8.039,7.857,14.067,15.96,14.067H97.59v65.882L59.374,453.42c-4.937,4.029-5.505,11.429-1.094,16.171c4.025,4.328,10.844,4.519,15.423,0.781l23.887-19.499v10.762c0,5.91,4.46,11.072,10.359,11.454c6.463,0.418,11.835-4.701,11.835-11.073v-11.143l24.18,19.739c4.745,3.876,11.739,3.169,15.614-1.578c3.876-4.747,3.168-11.739-1.579-15.614l-38.216-31.197V356.34h52.976c8.037,0,14.679-5.9,15.877-13.602l3.866,0.998l13.838,108.301c1.686,13.198,13.746,22.568,26.996,20.879C246.557,471.226,255.905,459.139,254.216,445.92z"/></g></g><g><g><circle cx=134.79 cy=83.273 r=44.386 /></g></g><g><g><path d="M495.354,259.884H270.076c-9.193,0-16.646,7.453-16.646,16.646s7.453,16.646,16.646,16.646h2.219v168.841c0,6.128,4.968,11.097,11.097,11.097s11.097-4.969,11.097-11.097V293.176H472.05v168.841c0,6.128,4.968,11.097,11.097,11.097s11.097-4.969,11.097-11.097V293.176h1.11c9.193,0,16.646-7.453,16.646-16.646C512,267.336,504.548,259.884,495.354,259.884z"/></g></g><g><g><path d="M493.94,228.076h-76.417c-5.517,0-9.988,4.471-9.988,9.988c0,5.517,4.471,9.988,9.988,9.988h76.417c5.517,0,9.988-4.471,9.988-9.988C503.928,232.547,499.457,228.076,493.94,228.076z"/></g></g><g><g><path d="M493.94,199.592h-76.417c-5.517,0-9.988,4.471-9.988,9.988s4.471,9.988,9.988,9.988h76.417c5.517,0,9.988-4.471,9.988-9.988S499.457,199.592,493.94,199.592z"/></g></g><g><g><path d="M493.94,171.11h-76.417c-5.517,0-9.988,4.471-9.988,9.988s4.471,9.988,9.988,9.988h76.417c5.517,0,9.988-4.471,9.988-9.988S499.457,171.11,493.94,171.11z"/></g></g><g><g><path d="M493.94,142.626h-76.417c-5.517,0-9.988,4.471-9.988,9.988s4.471,9.988,9.988,9.988h76.417c5.517,0,9.988-4.471,9.988-9.988S499.457,142.626,493.94,142.626z"/></g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g><g></g></svg>"#
  
  private let style: String = """
    <style media="print">
      @media print and (width: 21cm) and (height: 29.7cm) {
        @page {
          margin: 1cm;
        }
      }
    </style>
    <style media="screen">
      svg {
        margin-top: 1%;
        margin-left: 1%;
        margin-right: auto;
        padding-bottom: 2vh;
        height: 95vh;
        width: 98%;
      }
      img {
        display: block;
        margin-left: auto;
        margin-right: auto;
      }
      pre { font-size: 28px; }
      tspan { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }
      body { background-color: rgb(247,247,247); }
      @media (prefers-color-scheme: dark) {
        pre, h1 { color: rgb(247,247,247); }
        svg { filter: drop-shadow(3px 3px 3px rgb(255, 255, 255)); filter: invert(1); }
        body {
          background-color: rgb(20,20,20);
          background-image: radial-gradient(circle, rgb(50,50,50), rgb(20,20,20));
        }
      }
    </style>
    """

  private let script: String = """
    <link href="https://cdnjs.cloudflare.com/ajax/libs/jsoneditor/9.4.1/jsoneditor.min.css" rel="stylesheet" type="text/css">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jsoneditor/9.4.1/jsoneditor.min.js"></script>
    <div id="jsoneditor" style="width: 50%; height: 95vh; margin-left: 22%; padding: 2vh; margin-top: 5vh;"></div>
    <script>new JSONEditor(document.getElementById("jsoneditor"), {},
    """

  private var raw: String {
    let head: String = "<html lang=\"en\"><head>" + meta + style + """
      <link rel=\"icon\" href=\"data:,\"><script type="text/javascript">
      function fnOnError(msg,url,lineno){ return true; }
      window.onerror = fnOnError;
      </script></head>
      <script type="text/javascript">
      function toggle() {
        const e = document.getElementsByClassName("c")[0];
        if (e) { e.style.display = ((e.style.display!='none') ? 'none' : 'block'); }
      }
      </script>
      <body onclick=\"toggle()\">
      """
    let tail: String = "</body>\n</html>\n"
    if let json = json {
      return type + head + bodyContent + script + json + ")</script>" + tail
    }
    return type + head + bodyContent + tail
  }
}
