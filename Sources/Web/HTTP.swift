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
import Helpers

#if canImport(WASILibc)

public class HTTP {
  public init(handler: @escaping (Request) -> Response) { self.handler = handler }
  public var port: Int = 0
  public let handler: (Request) -> Response
  public func start() { }
  public func stop() { }
  deinit { stop() }
}
#else

import Dispatch

#if canImport(CRT)
  import CRT
  import WinSDK
#elseif canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#elseif canImport(WASILibc)
  import WASILibc
#endif

#if !os(Windows)
  typealias SOCKET = Int32
#endif

public class HTTP {
  public init(handler: @escaping (Request) -> Response) { self.handler = handler }
  public var port: Int = 8008
  public let handler: (Request) -> Response
  private static let staticSyncQ = DispatchQueue(label: "com.http.server.StaticSyncQ")
  private static var dispatchQueue = DispatchQueue(
    label: "com.http.server.queue", qos: .userInteractive)
  private static var _serverActive = false
  private static var server: Server? = nil

  static var serverActive: Bool {
    get { return staticSyncQ.sync { _serverActive } }
    set { staticSyncQ.sync { _serverActive = newValue } }
  }

  public func start() {

    func runServer() throws {
      if HTTP.serverActive { return }
      HTTP.server = try Server(port: UInt16(port))
      HTTP.serverActive = true
      while HTTP.serverActive {
        do {
          let httpServer = try HTTP.server!.listen()
          let request = try httpServer.request()
          try httpServer.respond(with: handler(request))
        } catch { if HTTP.serverActive {} }
      }
    }
    HTTP.dispatchQueue.async { do { try runServer() } catch {} }
  }
  public func stop() {
    HTTP.serverActive = false
    try? HTTP.server?.stop()
  }

  deinit { stop() }
}

extension UInt16 { public init(networkByteOrder input: UInt16) { self.init(bigEndian: input) } }

class TCPSocket: CustomStringConvertible {
  #if !os(Windows)
    #if os(Linux) || os(Android) || os(FreeBSD)
      private let sendFlags = CInt(MSG_NOSIGNAL)
    #else
      private let sendFlags = CInt(0)
    #endif
  #endif
  var description: String {
    return "TCPSocket @ 0x" + String(unsafeBitCast(self, to: UInt.self), radix: 16)
  }
  let listening: Bool
  private var socket: SOCKET!
  private var socketAddress = UnsafeMutablePointer<sockaddr_in>.allocate(capacity: 1)
  private(set) var port: UInt16
  private func isNotNegative(r: CInt) -> Bool { return r != -1 }
  private func isZero(r: CInt) -> Bool { return r == 0 }
  private func attempt<T>(
    _ name: String, file: String = #file, line: UInt = #line, valid: (T) -> Bool,
    _ b: @autoclosure () -> T
  ) throws -> T {
    let r = b()
    guard valid(r) else {
      throw HTTP.ServerError(operation: name, errno: errno, file: file, line: line)
    }
    return r
  }
  init(socket: SOCKET) {
    self.socket = socket
    self.port = 0
    listening = false
  }
  init(port: UInt16?) throws {
    listening = true
    self.port = 0
    #if os(Windows)
      socket = try attempt(
        "WSASocketW", valid: { $0 != INVALID_SOCKET },
        WSASocketW(AF_INET, SOCK_STREAM, IPPROTO_TCP.rawValue, nil, 0, DWORD(WSA_FLAG_OVERLAPPED)))
      var value: Int8 = 1
      _ = try attempt(
        "setsockopt", valid: { $0 == 0 },
        setsockopt(
          socket, SOL_SOCKET, SO_REUSEADDR, &value, Int32(MemoryLayout.size(ofValue: value))))
    #else
      #if os(Linux) && !os(Android)
        let SOCKSTREAM = Int32(SOCK_STREAM.rawValue)
      #else
        let SOCKSTREAM = SOCK_STREAM
      #endif
      #if canImport(Darwin)
        socket = try attempt(
          "socket", valid: { $0 >= 0 }, Darwin.socket(AF_INET, SOCKSTREAM, Int32(IPPROTO_TCP)))
      #else
        socket = try attempt(
          "socket", valid: { $0 >= 0 }, SwiftGlibc.socket(AF_INET, SOCKSTREAM, Int32(IPPROTO_TCP)))
      #endif

      var on: CInt = 1
      _ = try attempt(
        "setsockopt", valid: { $0 == 0 },
        setsockopt(socket, SOL_SOCKET, SO_REUSEADDR, &on, socklen_t(MemoryLayout<CInt>.size)))
    #endif
    let sa = createSockaddr(port)
    socketAddress.initialize(to: sa)
    try socketAddress.withMemoryRebound(
      to: sockaddr.self,
      capacity: MemoryLayout<sockaddr>.size,
      {
        let addr = UnsafePointer<sockaddr>($0)
        _ = try attempt(
          "bind", valid: isZero, bind(socket, addr, socklen_t(MemoryLayout<sockaddr>.size)))
        _ = try attempt("listen", valid: isZero, listen(socket, SOMAXCONN))
      }
    )
    var actualSA = sockaddr_in()
    withUnsafeMutablePointer(to: &actualSA) { ptr in
      ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        (ptr: UnsafeMutablePointer<sockaddr>) in var len = socklen_t(MemoryLayout<sockaddr>.size)
        getsockname(socket, ptr, &len)
      }
    }
    self.port = UInt16(networkByteOrder: actualSA.sin_port)
  }
  private func createSockaddr(_ port: UInt16?) -> sockaddr_in {
    let addr = UInt32(INADDR_LOOPBACK).bigEndian
    let netPort = UInt16(bigEndian: port ?? 0)
    #if os(Android)
      return sockaddr_in(
        sin_family: sa_family_t(AF_INET), sin_port: netPort, sin_addr: in_addr(s_addr: addr),
        __pad: (0, 0, 0, 0, 0, 0, 0, 0))
    #elseif os(Linux)
      return sockaddr_in(
        sin_family: sa_family_t(AF_INET), sin_port: netPort, sin_addr: in_addr(s_addr: addr),
        sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
    #elseif os(Windows)
      return sockaddr_in(
        sin_family: ADDRESS_FAMILY(AF_INET), sin_port: USHORT(netPort),
        sin_addr: IN_ADDR(S_un: in_addr.__Unnamed_union_S_un(S_addr: addr)),
        sin_zero: (CHAR(0), CHAR(0), CHAR(0), CHAR(0), CHAR(0), CHAR(0), CHAR(0), CHAR(0)))
    #else
      return sockaddr_in(
        sin_len: 0, sin_family: sa_family_t(AF_INET), sin_port: netPort,
        sin_addr: in_addr(s_addr: addr), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
    #endif
  }
  func acceptConnection() throws -> TCPSocket {
    guard listening else { fatalError("Trying to listen on a client connection socket") }
    let connection: SOCKET = try socketAddress.withMemoryRebound(
      to: sockaddr.self,
      capacity: MemoryLayout<sockaddr>.size,
      {
        let addr = UnsafeMutablePointer<sockaddr>($0)
        var sockLen = socklen_t(MemoryLayout<sockaddr>.size)
        #if os(Windows)
          let connectionSocket = try attempt(
            "WSAAccept", valid: { $0 != INVALID_SOCKET }, WSAAccept(socket, addr, &sockLen, nil, 0))
        #else
          let connectionSocket = try attempt(
            "accept", valid: { $0 >= 0 }, accept(socket, addr, &sockLen))
        #endif
        #if canImport(Darwin)
          // Disable SIGPIPEs when writing to closed sockets
          var on: CInt = 1
          guard
            setsockopt(
              connectionSocket, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<CInt>.size))
              == 0
          else {
            close(connectionSocket)
            throw HTTP.ServerError.init(
              operation: "setsockopt", errno: errno, file: #file, line: #line)
          }
        #endif
        return connectionSocket
      }
    )
    return TCPSocket(socket: connection)
  }
  func readData() throws -> Data? {
    guard let connectionSocket = socket else { throw InternalServerError.socketAlreadyClosed }
    var buffer = [CChar](repeating: 0, count: 4096)
    #if os(Windows)
      var dwNumberOfBytesRecieved: DWORD = 0
      try buffer.withUnsafeMutableBufferPointer {
        var wsaBuffer: WSABUF = WSABUF(len: ULONG($0.count), buf: $0.baseAddress)
        var flags: DWORD = 0
        _ = try attempt(
          "WSARecv", valid: { $0 != SOCKET_ERROR },
          WSARecv(connectionSocket, &wsaBuffer, 1, &dwNumberOfBytesRecieved, &flags, nil, nil))
      }
      let length = Int(dwNumberOfBytesRecieved)
    #else
      let length = try attempt(
        "read", valid: { $0 >= 0 }, read(connectionSocket, &buffer, buffer.count))
    #endif
    guard length > 0 else { return nil }
    return Data(bytes: buffer, count: length)
  }
  func writeRawData(_ data: Data) throws {
    guard let connectionSocket = socket else { throw InternalServerError.socketAlreadyClosed }
    #if os(Windows)
      _ = try data.withUnsafeBytes {
        var dwNumberOfBytesSent: DWORD = 0
        var wsaBuffer: WSABUF = WSABUF(
          len: ULONG(data.count),
          buf: UnsafeMutablePointer<CHAR>(mutating: $0.bindMemory(to: CHAR.self).baseAddress))
        _ = try attempt(
          "WSASend", valid: { $0 != SOCKET_ERROR },
          WSASend(connectionSocket, &wsaBuffer, 1, &dwNumberOfBytesSent, 0, nil, nil))
      }
    #else
      _ = try data.withUnsafeBytes { ptr in
        try attempt(
          "send", valid: { $0 == data.count },
          CInt(send(connectionSocket, ptr.baseAddress!, data.count, sendFlags)))
      }
    #endif
  }
  func writeData(header: String, bodyData: Data) throws {
    var totalData = Data(header.utf8)
    totalData.append(bodyData)
    try writeRawData(totalData)
  }
  func closeSocket() throws {
    guard socket != nil else { return }
    #if os(Windows)
      if listening { shutdown(socket, SD_BOTH) }
      closesocket(socket)
    #else
      if listening { shutdown(socket, CInt(SHUT_RDWR)) }
      close(socket)
    #endif
    socket = nil
  }
  deinit { try? closeSocket() }
}
#endif

public struct Headers {
  public static let VERSION = "HTTP/1.1"
  public static let CRLF = "\r\n"
  public static let CRLF2 = CRLF + CRLF
  public static let EMPTY = ""
  public static let SPACE = " "
}

extension HTTP {

  class Server: CustomStringConvertible {
    public var description: String {
      return "HTTPServer @ 0x" + String(unsafeBitCast(self, to: UInt.self), radix: 16)
    }
#if !canImport(WASILibc)
    struct SocketDataReader {
      private let tcpSocket: TCPSocket
      private var buffer = Data()
      init(socket: TCPSocket) { tcpSocket = socket }
      mutating func readBlockSeparated(by separatorData: Data) throws -> Data {
        var range = buffer.range(of: separatorData)
        while range == nil {
          guard let data = try tcpSocket.readData() else { break }
          buffer.append(data)
          range = buffer.range(of: separatorData)
        }
        guard let r = range else { throw InternalServerError.requestTooShort }
        let result = buffer.prefix(upTo: r.lowerBound)
        buffer = buffer.suffix(from: r.upperBound)
        return result
      }
      mutating func readBytes(count: Int) throws -> Data {
        while buffer.count < count {
          guard let data = try tcpSocket.readData() else { break }

          buffer.append(data)
        }
        guard buffer.count >= count else { throw InternalServerError.requestTooShort }
        let endIndex = buffer.startIndex + count
        let result = buffer[buffer.startIndex..<endIndex]
        buffer = buffer[endIndex...]
        return result
      }
    }
    let tcpSocket: TCPSocket

    public init(port: UInt16?) throws { tcpSocket = try TCPSocket(port: port) }
    init(socket: TCPSocket) { tcpSocket = socket }
    public class func create(port: UInt16?) throws -> Server { return try Server(port: port) }
    public func listen() throws -> Server {
      let connection = try tcpSocket.acceptConnection()
      return Server(socket: connection)
    }
    public func stop() throws { try tcpSocket.closeSocket() }
    func request() throws -> Request {
      var reader = SocketDataReader(socket: tcpSocket)
      let headerData = try reader.readBlockSeparated(by: Headers.CRLF2.data(using: .ascii)!)
      guard let headerString = String(bytes: headerData, encoding: .ascii) else {
        throw InternalServerError.requestTooShort
      }
      var request = try Request(header: headerString)
      if let contentLength = request.getHeader(for: "Content-Length"),
        let length = Int(contentLength), length > 0
      {
        let messageData = try reader.readBytes(count: length)
        request.messageData = messageData
        request.messageBody = String(bytes: messageData, encoding: .utf8)
        return request
      } else if (request.getHeader(for: "Transfer-Encoding") ?? "").lowercased() == "chunked" {
        // According to RFC7230 https://tools.ietf.org/html/rfc7230#section-3
        // We receive messageBody after the headers, so we need read from socket minimum 2 times
        //
        // HTTP-message structure
        //
        // start-line
        // *( header-field CRLF )
        // CRLF
        // [ message-body ]
        // We receives '{numofbytes}\r\n{data}\r\n'

        // There maybe some part of the body in the initial data

        let bodySeparator = Headers.CRLF.data(using: .ascii)!
        var messageData = Data()
        var finished = false
        while !finished {
          let chunkSizeData = try reader.readBlockSeparated(by: bodySeparator)
          // Should now have <num bytes>\r\n
          guard let number = String(bytes: chunkSizeData, encoding: .ascii),
            let chunkSize = Int(number, radix: 16)
          else { throw InternalServerError.requestTooShort }
          if chunkSize == 0 {
            finished = true
            break
          }
          let chunkData = try reader.readBytes(count: chunkSize)
          messageData.append(chunkData)
          // Next 2 bytes should be \r\n to indicate the end of the chunk
          let endOfChunk = try reader.readBytes(count: bodySeparator.count)
          guard endOfChunk == bodySeparator else { throw InternalServerError.requestTooShort }
        }
        request.messageData = messageData
        request.messageBody = String(bytes: messageData, encoding: .utf8)
      }
      return request
    }
    func respond(with response: Response) throws {
      try tcpSocket.writeData(header: response.header, bodyData: response.bodyData)
    }
    #endif
  }

  public struct Request: CustomStringConvertible {
    enum Method: String {
      case HEAD
      case GET
      case POST
      case PUT
      case DELETE
    }
    enum Error: Swift.Error {
      case invalidURI
      case invalidMethod
      case headerEndNotFound
    }
    let method: Method
    public let uri: String
    private(set) var headers: [String] = []
    private(set) var parameters: [String: String] = [:]
    var messageBody: String?
    var messageData: Data?
    public var description: String { return "\(method.rawValue) \(uri)" }
    public subscript(_ key: String) -> String? { parameters[key] }
    init(header: String) throws {
      self.headers = header.components(separatedBy: Headers.CRLF)
      guard headers.count > 0 else { throw Error.invalidURI }
      let uriParts = headers[0].components(separatedBy: " ")
      guard uriParts.count > 2, let methodName = Method(rawValue: uriParts[0]) else {
        throw Error.invalidMethod
      }
      method = methodName
      let params = uriParts[1].split(separator: "?", maxSplits: 1, omittingEmptySubsequences: true)
      if params.count > 1 {
        for arg in params[1].split(separator: "&", omittingEmptySubsequences: true) {
          let keyValue = arg.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
          guard !keyValue.isEmpty else { continue }
          guard let key = keyValue[0].removingPercentEncoding else { throw Error.invalidURI }
          guard let value = (keyValue.count > 1) ? keyValue[1].removingPercentEncoding : "" else {
            throw Error.invalidURI
          }
          self.parameters[key] = value
        }
      }
      self.uri = String(params[0])
    }
    public func getCommaSeparatedHeaders() -> String {
      var allHeaders = ""
      for header in headers { allHeaders += header + "," }
      return allHeaders
    }
    public func getHeader(for key: String) -> String? {
      let lookup = key.lowercased()
      for header in headers {
        let parts = header.components(separatedBy: ":")
        if parts[0].lowercased() == lookup {
          return parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " "))
        }
      }
      return nil
    }
    public func headersAsJSON() throws -> Data {
      var headerDict: [String: String] = [:]
      for header in headers {
        if header.hasPrefix(method.rawValue) {
          headerDict["uri"] = header
          continue
        }
        let parts = header.components(separatedBy: ":")
        if parts.count > 1 {
          headerDict[parts[0]] = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " "))
        }
      }
      // Include the body as a Base64 Encoded entry
      if let bodyData = messageData ?? messageBody?.data(using: .utf8) {
        headerDict["x-base64-body"] = bodyData.base64EncodedString()
      }
      if #available(macOS 10.13, *) {
        return try JSONSerialization.data(withJSONObject: headerDict, options: .sortedKeys)
      } else {
        return try JSONSerialization.data(withJSONObject: headerDict)
      }
    }
  }

  public struct Response {
    public enum ResponseCode: Int {
      case OK = 200
      case FOUND = 302
      case BAD_REQUEST = 400
      case NOT_FOUND = 404
      case METHOD_NOT_ALLOWED = 405
      case SERVER_ERROR = 500
    }

    private let responseCode: Int
    private var headers: [String]
    public let bodyData: Data
    public init(responseCode: Int = 200, headers: [String] = [], bodyData: Data) {
      self.responseCode = responseCode
      self.headers = headers
      self.bodyData = bodyData
      for header in headers { if header.lowercased().hasPrefix("content-length") { return } }
      self.headers.append("Content-Length: \(bodyData.count)")
    }
    public init(html: HTML) {
      #if os(Linux)
        let headers = ["Content-Type: text/html; charset=utf-8", "Content-Encoding: gzip"]
        let bodyData = html.data.gzipped()
      #else
        let headers = ["Content-Type: text/html; charset=utf-8"]
        let bodyData = html.data
      #endif
      self.init(responseCode: 200, headers: headers, bodyData: bodyData)
    }
    public init(response: ResponseCode, headers: [String] = [], bodyData: Data = Data()) {
      self.init(responseCode: response.rawValue, headers: headers, bodyData: bodyData)
    }
    public init(response: ResponseCode, headers: String = Headers.EMPTY, bodyData: Data) {
      let headers = headers.split(separator: "\r\n").map { String($0) }
      self.init(responseCode: response.rawValue, headers: headers, bodyData: bodyData)
    }
    public init(response: ResponseCode, headers: String = Headers.EMPTY, body: String) throws {
      guard let data = body.data(using: .utf8) else { throw InternalServerError.badBody }
      self.init(response: response, headers: headers, bodyData: data)
    }
    public init?(responseCode: Int = 200, headers: [String] = [], body: String) {
      guard let data = body.data(using: .utf8) else { return nil }
      self.init(responseCode: responseCode, headers: headers, bodyData: data)
    }
    public var header: String {
      let responseCodeName = ""
      let statusLine =
        Headers.VERSION + Headers.SPACE + "\(responseCode)" + Headers.SPACE + "\(responseCodeName)"
      let header = headers.joined(separator: "\r\n")
      return statusLine + (header != Headers.EMPTY ? Headers.CRLF + header : Headers.EMPTY)
        + Headers.CRLF2
    }
    mutating func addHeader(_ header: String) { headers.append(header) }
  }

  public struct ServerError: Error {
    let operation: String
    let errno: CInt
    let file: String
    let line: UInt
    public var _code: Int { return Int(errno) }
    public var _domain: String { return NSPOSIXErrorDomain }
  }
}

enum InternalServerError: Error {
  case socketAlreadyClosed
  case requestTooShort
  case badBody
}

#if canImport(Glibc)
  import CZLib

  extension Data {
    /// Whether the receiver is compressed in gzip format.
    public var isGzipped: Bool { self.starts(with: [0x1f, 0x8b]) }
    /// Create a new `Data` instance by compressing the receiver using zlib.
    /// Throws an error if compression failed.
    ///
    /// - Parameter level: Compression level.
    /// - Returns: Gzip-compressed `Data` instance.
    /// - Throws: `GzipError`
    public func gzipped(level: CompressionLevel = .defaultCompression) -> Data {
      guard !self.isEmpty else { return Data() }
      var stream = z_stream()
      var status: Int32
      status = deflateInit2_(
        &stream, level.rawValue, Z_DEFLATED, MAX_WBITS + 16, MAX_MEM_LEVEL, Z_DEFAULT_STRATEGY,
        ZLIB_VERSION, Int32(DataSize.stream))
      guard status == Z_OK else { return self }
      var data = Data(capacity: DataSize.chunk)
      repeat {
        if Int(stream.total_out) >= data.count { data.count += DataSize.chunk }
        let inputCount = self.count
        let outputCount = data.count
        self.withUnsafeBytes { (inputPointer: UnsafeRawBufferPointer) in
          stream.next_in = UnsafeMutablePointer<Bytef>(
            mutating: inputPointer.bindMemory(to: Bytef.self).baseAddress!
          ).advanced(by: Int(stream.total_in))
          stream.avail_in = uint(inputCount) - uInt(stream.total_in)
          data.withUnsafeMutableBytes { (outputPointer: UnsafeMutableRawBufferPointer) in
            stream.next_out = outputPointer.bindMemory(to: Bytef.self).baseAddress!.advanced(
              by: Int(stream.total_out))
            stream.avail_out = uInt(outputCount) - uInt(stream.total_out)
            status = deflate(&stream, Z_FINISH)
            stream.next_out = nil
          }
          stream.next_in = nil
        }
      } while stream.avail_out == 0
      guard deflateEnd(&stream) == Z_OK, status == Z_STREAM_END else { return self }
      data.count = Int(stream.total_out)
      return data
    }
  }

  private enum DataSize {
    static let chunk = 1 << 14
    static let stream = MemoryLayout<z_stream>.size
  }

  /// Compression level whose rawValue is based on the zlib's constants.
  public struct CompressionLevel: RawRepresentable {
    /// Compression level in the range of `0` (no compression) to `9` (maximum compression).
    public let rawValue: Int32
    public static let noCompression = CompressionLevel(Z_NO_COMPRESSION)
    public static let bestSpeed = CompressionLevel(Z_BEST_SPEED)
    public static let bestCompression = CompressionLevel(Z_BEST_COMPRESSION)
    public static let defaultCompression = CompressionLevel(Z_DEFAULT_COMPRESSION)
    public init(rawValue: Int32) { self.rawValue = rawValue }
    public init(_ rawValue: Int32) { self.rawValue = rawValue }
  }
#endif
