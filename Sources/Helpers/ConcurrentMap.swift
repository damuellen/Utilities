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
#if canImport(WASILibc)
extension RandomAccessCollection {
  /// Returns `self.map(transform)`, computed in parallel.
  @inlinable
  public func concurrentMap<E>(_ transform: (Element) -> E)
    -> [E]
  {
    self.map(transform)
  }
}
#else
import Dispatch

extension RandomAccessCollection {
  /// Returns `self.map(transform)`, computed in parallel.
  @inlinable
  public func concurrentMap<E>(_ transform: (Element) -> E)
    -> [E]
  {
    let n = self.count
    let batchCount = ProcessInfo.processInfo.activeProcessorCount * 4
    if batchCount > n { return self.map(transform) }
    return Array(unsafeUninitializedCapacity: n) {
      uninitializedMemory, resultCount in resultCount = n
      let baseAddress = uninitializedMemory.baseAddress!
      DispatchQueue.concurrentPerform(iterations: batchCount) { b in
        let startOffset: Int = b * n / batchCount
        let endOffset: Int = (b + 1) * n / batchCount
        var sourceIndex: Index = index(self.startIndex, offsetBy: startOffset)
        for p in baseAddress + startOffset..<baseAddress + endOffset {
          p.initialize(to: transform(self[sourceIndex]))
          formIndex(after: &sourceIndex)
        }
      }
    }
  }
}
#endif
