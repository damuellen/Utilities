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

#if canImport(FoundationXML)
  import FoundationXML
#endif
public enum XMLParseError: Error { case unexpectedError }

public final class XML {
  public var name: String
  public var attributes: [String: String] = [:]
  public var value: String = ""
  public internal(set) var children: [XML] = []
  weak var parent: XML?
  private init(xml: XML) {
    self.name = xml.name
    self.attributes = xml.attributes
    self.value = xml.value
    self.addChildren(xml.children)
    self.parent = nil
  }
  init(name: String, attributes: [String: Any] = [:]) {
    self.name = name
    self.addAttributes(attributes)
  }
  public convenience init(atPath: String) throws {
    let url = URL(fileURLWithPath: atPath)
    let fileHandle = try FileHandle(forReadingFrom: url)
    let data = fileHandle.readDataToEndOfFile()
    try fileHandle.close()
    let parser = Parser(data: data)
    parser.parse()
    guard let xml = parser.root else { throw XMLParseError.unexpectedError }
    self.init(xml: xml)
  }
  public convenience init(data: Data) throws {
    let parser = Parser(data: data)
    parser.parse()
    guard let xml = parser.root else { throw XMLParseError.unexpectedError }
    self.init(xml: xml)
  }
  func addAttribute(name: String, value: Any) { self.attributes[name] = String(describing: value) }
  func addAttributes(_ attributes: [String: Any]) {
    for (key, value) in attributes { self.addAttribute(name: key, value: value) }
  }
  func addChild(_ xml: XML) {
    children.append(xml)
    xml.parent = self
  }
  func addChildren(_ xmls: [XML]) { xmls.forEach { self.addChild($0) } }
}

private class Parser: NSObject, XMLParserDelegate {
  var root: XML?
  private let data: Data
  private weak var currentElement: XML?
  init(data: Data) { self.data = data }
  func parse() {
    let parser = XMLParser(data: data)
    parser.delegate = self
    let _ = parser.parse()
  }
  func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?,
    attributes attributeDict: [String: String] = [:]
  ) {
    let element = XML(name: elementName, attributes: attributeDict)
    if root == nil {
      root = element
      currentElement = element
    } else {
      currentElement?.addChild(element)
      currentElement = element
    }
  }
  func parser(_ parser: XMLParser, foundCharacters string: String) {
    currentElement?.value += string
  }
  func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) { currentElement = currentElement?.parent }
}
