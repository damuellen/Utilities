#if canImport(Glibc)
  @_exported import Glibc
#elseif os(Windows)
  @_exported import CRT
#elseif canImport(WASILibc)
  @_exported import WASILibc
#else
  @_exported import Darwin.C
#endif
