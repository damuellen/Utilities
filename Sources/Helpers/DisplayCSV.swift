
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
#if canImport(PythonKit)
 import PythonKit
 extension CSVReader {
   public func display(_ range: Array<Any>.Indices? = nil) {
     let html = """
     <html>
     <head>
     <style>
     table {
       font-family: sans-serif;
       font-size: small;
       border-collapse: collapse;
       table-layout: auto;
     }
     td, th {
       border: 1px solid #ddd;
       padding: 4px;
       text-align: right;
       overflow: hidden;
       text-overflow: ellipsis;
       max-width: 10%;
     }
     tr:nth-child(even) { background-color: #f2f2f2; }
     tr:hover { background-color: #ddd; }
     th {
       padding-top: 6px;
       padding-bottom: 6px;
       text-align: center;
       background-color: Teal;
       color: white;
     }
     </style>
     </head>
     <body>
     """
     var table = "\n<table>\n"
     if let headerRow = headerRow {
       table += headerRow.isEmpty ? "" : "\t<tr>\n"
         + "\t\t<th>index</th>\n" + headerRow.map {
           "\t\t<th>" + $0.description + "</th>\n"
         }.joined() + "\t</tr>\n"
     }
     var rows: ArraySlice<[Double]>
     if let range = range {
       rows = dataRows[range]
     } else {
       if dataRows.count > 10 {
         rows = dataRows[..<5]
         rows.append(contentsOf: dataRows[(dataRows.endIndex-5)...])
       } else {
         rows = dataRows[...]
       }
     }
     table += rows.indices.map { i in
       "\t<tr>\n" + "\t\t<td>\(i)</td>\n" + rows[i].map {
         "\t\t<td>" + String(format: "%.2f", $0) + "</td>\n"
       }.joined() + "\t</tr>\n"
     }.joined()
     table += "</table>\n"

     let display = Python.import("IPython.display")
     display.display(display.HTML(data: html + table + "</body>\n</html>\n"))
   }
 }
 #endif
