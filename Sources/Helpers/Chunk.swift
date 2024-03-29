//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Algorithms open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// suffix(while:)
//===----------------------------------------------------------------------===//

extension BidirectionalCollection {
  /// Returns a subsequence containing the elements from the end until
  /// `predicate` returns `false` and skipping the remaining elements.
  ///
  /// - Parameter predicate: A closure that takes an element of the
  ///   sequence as its argument and returns `true` if the element should
  ///   be included or `false` if it should be excluded. Once the predicate
  ///   returns `false` it will not be called again.
  ///
  /// - Complexity: O(*n*), where *n* is the length of the collection.
  @inlinable
  public func suffix(
    while predicate: (Element) throws -> Bool
  ) rethrows -> SubSequence {
    try self[startOfSuffix(while: predicate)...]
  }
}

//===----------------------------------------------------------------------===//
// endOfPrefix(while:)
//===----------------------------------------------------------------------===//

extension Collection {
  /// Returns the exclusive upper bound of the prefix of elements that satisfy
  /// the predicate.
  ///
  /// - Parameter predicate: A closure that takes an element of the collection
  ///   as its argument and returns `true` if the element is part of the prefix
  ///   or `false` if it is not. Once the predicate returns `false` it will not
  ///   be called again.
  ///
  /// - Complexity: O(*n*), where *n* is the length of the collection.
  @inlinable
  internal func endOfPrefix(
    while predicate: (Element) throws -> Bool
  ) rethrows -> Index {
    var index = startIndex
    while try index != endIndex && predicate(self[index]) {
      formIndex(after: &index)
    }
    return index
  }
}

//===----------------------------------------------------------------------===//
// startOfSuffix(while:)
//===----------------------------------------------------------------------===//

extension BidirectionalCollection {
  /// Returns the inclusive lower bound of the suffix of elements that satisfy
  /// the predicate.
  ///
  /// - Parameter predicate: A closure that takes an element of the collection
  ///   as its argument and returns `true` if the element is part of the suffix
  ///   or `false` if it is not. Once the predicate returns `false` it will not
  ///   be called again.
  ///
  /// - Complexity: O(*n*), where *n* is the length of the collection.
  @inlinable
  internal func startOfSuffix(
    while predicate: (Element) throws -> Bool
  ) rethrows -> Index {
    var index = endIndex
    while index != startIndex {
      let after = index
      formIndex(before: &index)
      if try !predicate(self[index]) {
        return after
      }
    }
    return index
  }
}

/// A collection wrapper that iterates over the indices and elements of a
/// collection together.
public struct Indexed<Base: Collection> {
  /// The element type for an `Indexed` collection.
  public typealias Element = (index: Base.Index, element: Base.Element)

  /// The base collection.
  @usableFromInline
  internal let base: Base

  @inlinable
  internal init(base: Base) {
    self.base = base
  }
}

extension Indexed: Collection {
  @inlinable
  public var startIndex: Base.Index {
    base.startIndex
  }

  @inlinable
  public var endIndex: Base.Index {
    base.endIndex
  }

  @inlinable
  public subscript(position: Base.Index) -> Element {
    (index: position, element: base[position])
  }

  @inlinable
  public func index(after i: Base.Index) -> Base.Index {
    base.index(after: i)
  }

  @inlinable
  public func index(_ i: Base.Index, offsetBy distance: Int) -> Base.Index {
    base.index(i, offsetBy: distance)
  }

  @inlinable
  public func index(_ i: Base.Index, offsetBy distance: Int, limitedBy limit: Base.Index) -> Base
    .Index?
  {
    base.index(i, offsetBy: distance, limitedBy: limit)
  }

  @inlinable
  public func distance(from start: Base.Index, to end: Base.Index) -> Int {
    base.distance(from: start, to: end)
  }
}

extension Indexed: BidirectionalCollection where Base: BidirectionalCollection {
  @inlinable
  public func index(before i: Base.Index) -> Base.Index {
    base.index(before: i)
  }
}

extension Indexed: RandomAccessCollection where Base: RandomAccessCollection {}
extension Indexed: LazySequenceProtocol where Base: LazySequenceProtocol {}
extension Indexed: LazyCollectionProtocol where Base: LazyCollectionProtocol {}

//===----------------------------------------------------------------------===//
// indexed()
//===----------------------------------------------------------------------===//

extension Collection {
  /// Returns a collection of pairs *(i, x)*, where *i* represents an index of
  /// the collection, and *x* represents an element.
  ///
  /// This example iterates over the indices and elements of a set, building an
  /// array consisting of indices of names with five or fewer letters.
  ///
  ///     let names: Set = ["Sofia", "Camilla", "Martina", "Mateo", "Nicolás"]
  ///     var shorterIndices: [Set<String>.Index] = []
  ///     for (i, name) in names.indexed() {
  ///         if name.count <= 5 {
  ///             shorterIndices.append(i)
  ///         }
  ///     }
  ///
  /// Returns: A collection of paired indices and elements of this collection.
  @inlinable
  public func indexed() -> Indexed<Self> {
    Indexed(base: self)
  }
}

/// A collection wrapper that breaks a collection into chunks based on a
/// predicate.
///
/// Call `lazy.chunked(by:)` on a collection to create an instance of this type.
public struct ChunkedBy<Base: Collection, Subject> {
  /// The collection that this instance provides a view onto.
  @usableFromInline
  internal let base: Base

  /// The projection function.
  @usableFromInline
  internal let projection: (Base.Element) -> Subject

  /// The predicate.
  @usableFromInline
  internal let belongInSameGroup: (Subject, Subject) -> Bool

  /// The upper bound of the first chunk.
  @usableFromInline
  internal var firstUpperBound: Base.Index

  @inlinable
  internal init(
    base: Base,
    projection: @escaping (Base.Element) -> Subject,
    belongInSameGroup: @escaping (Subject, Subject) -> Bool
  ) {
    self.base = base
    self.projection = projection
    self.belongInSameGroup = belongInSameGroup
    self.firstUpperBound = base.startIndex

    if !base.isEmpty {
      firstUpperBound = endOfChunk(startingAt: base.startIndex)
    }
  }
}

extension ChunkedBy: LazyCollectionProtocol {
  /// A position in a chunked collection.
  public struct Index: Comparable {
    /// The range corresponding to the chunk at this position.
    @usableFromInline
    internal var baseRange: Range<Base.Index>

    @inlinable
    internal init(_ baseRange: Range<Base.Index>) {
      self.baseRange = baseRange
    }

    @inlinable
    public static func == (lhs: Index, rhs: Index) -> Bool {
      // Since each index represents the range of a disparate chunk, no two
      // unique indices will have the same lower bound.
      lhs.baseRange.lowerBound == rhs.baseRange.lowerBound
    }

    @inlinable
    public static func < (lhs: Index, rhs: Index) -> Bool {
      // Only use the lower bound to test for ordering, as above.
      lhs.baseRange.lowerBound < rhs.baseRange.lowerBound
    }
  }

  /// Returns the index in the base collection of the end of the chunk starting
  /// at the given index.
  @inlinable
  internal func endOfChunk(startingAt start: Base.Index) -> Base.Index {
    var subject = projection(base[start])

    return base[base.index(after: start)...].endOfPrefix(while: { element in
      let nextSubject = projection(element)
      defer { subject = nextSubject }
      return belongInSameGroup(subject, nextSubject)
    })
  }

  @inlinable
  public var startIndex: Index {
    Index(base.startIndex..<firstUpperBound)
  }

  @inlinable
  public var endIndex: Index {
    Index(base.endIndex..<base.endIndex)
  }

  @inlinable
  public func index(after i: Index) -> Index {
    precondition(i != endIndex, "Can't advance past endIndex")
    let upperBound = i.baseRange.upperBound
    guard upperBound != base.endIndex else { return endIndex }
    let end = endOfChunk(startingAt: upperBound)
    return Index(upperBound..<end)
  }

  @inlinable
  public subscript(position: Index) -> Base.SubSequence {
    precondition(position != endIndex, "Can't subscript using endIndex")
    return base[position.baseRange]
  }
}

extension ChunkedBy.Index: Hashable where Base.Index: Hashable {}

extension ChunkedBy: BidirectionalCollection
where Base: BidirectionalCollection {
  /// Returns the index in the base collection of the start of the chunk ending
  /// at the given index.
  @inlinable
  internal func startOfChunk(endingAt end: Base.Index) -> Base.Index {
    let indexBeforeEnd = base.index(before: end)
    var subject = projection(base[indexBeforeEnd])

    return base[..<indexBeforeEnd].startOfSuffix(while: { element in
      let nextSubject = projection(element)
      defer { subject = nextSubject }
      return belongInSameGroup(nextSubject, subject)
    })
  }

  @inlinable
  public func index(before i: Index) -> Index {
    precondition(i != startIndex, "Can't advance before startIndex")
    let start = startOfChunk(endingAt: i.baseRange.lowerBound)
    return Index(start..<i.baseRange.lowerBound)
  }
}

@available(*, deprecated, renamed: "ChunkedBy")
public typealias LazyChunked<Base: Collection, Subject> = ChunkedBy<Base, Subject>

@available(*, deprecated, renamed: "ChunkedBy")
public typealias Chunked<Base: Collection, Subject> = ChunkedBy<Base, Subject>

/// A collection wrapper that breaks a collection into chunks based on a
/// predicate.
///
/// Call `lazy.chunked(on:)` on a collection to create an instance of this type.
public struct ChunkedOn<Base: Collection, Subject> {
  @usableFromInline
  internal var chunked: ChunkedBy<Base, Subject>

  @inlinable
  internal init(
    base: Base,
    projection: @escaping (Base.Element) -> Subject,
    belongInSameGroup: @escaping (Subject, Subject) -> Bool
  ) {
    self.chunked = ChunkedBy(
      base: base, projection: projection, belongInSameGroup: belongInSameGroup)
  }
}

extension ChunkedOn: LazyCollectionProtocol {
  public typealias Index = ChunkedBy<Base, Subject>.Index

  @inlinable
  public var startIndex: Index {
    chunked.startIndex
  }

  @inlinable
  public var endIndex: Index {
    chunked.endIndex
  }

  @inlinable
  public subscript(position: Index) -> (Subject, Base.SubSequence) {
    let subsequence = chunked[position]
    let subject = chunked.projection(subsequence.first!)
    return (subject, subsequence)
  }

  @inlinable
  public func index(after i: Index) -> Index {
    chunked.index(after: i)
  }
}

extension ChunkedOn: BidirectionalCollection where Base: BidirectionalCollection {
  public func index(before i: Index) -> Index {
    chunked.index(before: i)
  }
}

//===----------------------------------------------------------------------===//
// lazy.chunked(by:) / lazy.chunked(on:)
//===----------------------------------------------------------------------===//
extension LazyCollectionProtocol {
  /// Returns a lazy collection of subsequences of this collection, chunked by
  /// the given predicate.
  ///
  /// - Complexity: O(*n*), because the start index is pre-computed.
  @inlinable
  public func chunked(
    by belongInSameGroup: @escaping (Element, Element) -> Bool
  ) -> ChunkedBy<Elements, Element> {
    ChunkedBy(
      base: elements,
      projection: { $0 },
      belongInSameGroup: belongInSameGroup)
  }

  /// Returns a lazy collection of subsequences of this collection, chunked by
  /// grouping elements that project to the same value.
  ///
  /// - Complexity: O(*n*), because the start index is pre-computed.
  @inlinable
  public func chunked<Subject: Equatable>(
    on projection: @escaping (Element) -> Subject
  ) -> ChunkedOn<Elements, Subject> {
    ChunkedOn(
      base: elements,
      projection: projection,
      belongInSameGroup: ==)
  }
}

//===----------------------------------------------------------------------===//
// chunked(by:) / chunked(on:)
//===----------------------------------------------------------------------===//
extension Collection {
  /// Returns a collection of subsequences of this collection, chunked by
  /// the given predicate.
  ///
  /// - Complexity: O(*n*), where *n* is the length of this collection.
  @inlinable
  public func chunked(
    by belongInSameGroup: (Element, Element) throws -> Bool
  ) rethrows -> [SubSequence] {
    guard !isEmpty else { return [] }
    var result: [SubSequence] = []

    var start = startIndex
    var current = self[start]

    for (index, element) in indexed().dropFirst() {
      if try !belongInSameGroup(current, element) {
        result.append(self[start..<index])
        start = index
      }
      current = element
    }

    if start != endIndex {
      result.append(self[start..<endIndex])
    }

    return result
  }

  /// Returns a collection of subsequences of this collection, chunked by
  /// grouping elements that project to the same value.
  ///
  /// - Complexity: O(*n*), where *n* is the length of this collection.
  @inlinable
  public func chunked<Subject: Equatable>(
    on projection: (Element) throws -> Subject
  ) rethrows -> [(Subject, SubSequence)] {
    guard !isEmpty else { return [] }
    var result: [(Subject, SubSequence)] = []

    var start = startIndex
    var subject = try projection(self[start])

    for (index, element) in indexed().dropFirst() {
      let nextSubject = try projection(element)
      if subject != nextSubject {
        result.append((subject, self[start..<index]))
        start = index
        subject = nextSubject
      }
    }

    if start != endIndex {
      result.append((subject, self[start..<endIndex]))
    }

    return result
  }
}

//===----------------------------------------------------------------------===//
// chunks(ofCount:)
//===----------------------------------------------------------------------===//
/// A collection that presents the elements of its base collection
/// in `SubSequence` chunks of any given count.
///
/// A `ChunkedByCount` is a lazy view on the base Collection, but it does not implicitly confer
/// laziness on algorithms applied to its result.  In other words, for ordinary collections `c`:
///
/// * `c.chunks(ofCount: 3)` does not create new storage
/// * `c.chunks(ofCount: 3).map(f)` maps eagerly and returns a new array
/// * `c.lazy.chunks(ofCount: 3).map(f)` maps lazily and returns a `LazyMapCollection`
public struct ChunkedByCount<Base: Collection> {

  public typealias Element = Base.SubSequence

  @usableFromInline
  internal let base: Base

  @usableFromInline
  internal let chunkCount: Int

  @usableFromInline
  internal var startUpperBound: Base.Index

  ///  Creates a view instance that presents the elements of `base`
  ///  in `SubSequence` chunks of the given count.
  ///
  /// - Complexity: O(*n*), because the start index is pre-computed.
  @inlinable
  internal init(_base: Base, _chunkCount: Int) {
    self.base = _base
    self.chunkCount = _chunkCount

    // Compute the start index upfront in order to make
    // start index a O(1) lookup.
    self.startUpperBound =
      _base.index(
        _base.startIndex, offsetBy: _chunkCount,
        limitedBy: _base.endIndex
      ) ?? _base.endIndex
  }
}

extension ChunkedByCount: Collection {
  public struct Index {
    @usableFromInline
    internal let baseRange: Range<Base.Index>

    @inlinable
    internal init(_baseRange: Range<Base.Index>) {
      self.baseRange = _baseRange
    }
  }

  /// - Complexity: O(1)
  @inlinable
  public var startIndex: Index {
    Index(_baseRange: base.startIndex..<startUpperBound)
  }
  @inlinable
  public var endIndex: Index {
    Index(_baseRange: base.endIndex..<base.endIndex)
  }

  /// - Complexity: O(1)
  @inlinable
  public subscript(i: Index) -> Element {
    precondition(i < endIndex, "Index out of range")
    return base[i.baseRange]
  }

  @inlinable
  public func index(after i: Index) -> Index {
    precondition(i < endIndex, "Advancing past end index")
    let baseIdx =
      base.index(
        i.baseRange.upperBound, offsetBy: chunkCount,
        limitedBy: base.endIndex
      ) ?? base.endIndex
    return Index(_baseRange: i.baseRange.upperBound..<baseIdx)
  }
}

extension ChunkedByCount.Index: Comparable {
  @inlinable
  public static func == (
    lhs: ChunkedByCount.Index,
    rhs: ChunkedByCount.Index
  ) -> Bool {
    lhs.baseRange.lowerBound == rhs.baseRange.lowerBound
  }

  @inlinable
  public static func < (
    lhs: ChunkedByCount.Index,
    rhs: ChunkedByCount.Index
  ) -> Bool {
    lhs.baseRange.lowerBound < rhs.baseRange.lowerBound
  }
}

extension ChunkedByCount:
  BidirectionalCollection, RandomAccessCollection
where Base: RandomAccessCollection {
  @inlinable
  public func index(before i: Index) -> Index {
    precondition(i > startIndex, "Advancing past start index")

    var offset = chunkCount
    if i.baseRange.lowerBound == base.endIndex {
      let remainder = base.count % chunkCount
      if remainder != 0 {
        offset = remainder
      }
    }

    let baseIdx =
      base.index(
        i.baseRange.lowerBound, offsetBy: -offset,
        limitedBy: base.startIndex
      ) ?? base.startIndex
    return Index(_baseRange: baseIdx..<i.baseRange.lowerBound)
  }
}

extension ChunkedByCount {
  @inlinable
  public func distance(from start: Index, to end: Index) -> Int {
    let distance =
      base.distance(
        from: start.baseRange.lowerBound,
        to: end.baseRange.lowerBound)
    let (quotient, remainder) =
      distance.quotientAndRemainder(dividingBy: chunkCount)
    return quotient + remainder.signum()
  }

  @inlinable
  public var count: Int {
    let (quotient, remainder) =
      base.count.quotientAndRemainder(dividingBy: chunkCount)
    return quotient + remainder.signum()
  }

  @inlinable
  public func index(
    _ i: Index, offsetBy offset: Int, limitedBy limit: Index
  ) -> Index? {
    guard offset != 0 else { return i }
    guard limit != i else { return nil }

    if offset > 0 {
      return limit > i
        ? offsetForward(i, offsetBy: offset, limit: limit)
        : offsetForward(i, offsetBy: offset)
    } else {
      return limit < i
        ? offsetBackward(i, offsetBy: offset, limit: limit)
        : offsetBackward(i, offsetBy: offset)
    }
  }

  @inlinable
  public func index(_ i: Index, offsetBy distance: Int) -> Index {
    guard distance != 0 else { return i }

    let idx =
      distance > 0
      ? offsetForward(i, offsetBy: distance)
      : offsetBackward(i, offsetBy: distance)
    guard let index = idx else {
      fatalError("Out of bounds")
    }
    return index
  }

  @inlinable
  internal func offsetForward(
    _ i: Index, offsetBy distance: Int, limit: Index? = nil
  ) -> Index? {
    assert(distance > 0)

    return makeOffsetIndex(
      from: i, baseBound: base.endIndex,
      distance: distance, baseDistance: distance * chunkCount,
      limit: limit, by: >
    )
  }

  // Convenience to compute offset backward base distance.
  @inlinable
  internal func computeOffsetBackwardBaseDistance(
    _ i: Index, _ distance: Int
  ) -> Int {
    if i == endIndex {
      let remainder = base.count % chunkCount
      // We have to take it into account when calculating offsets.
      if remainder != 0 {
        // Distance "minus" one(at this point distance is negative)
        // because we need to adjust for the last position that have
        // a variadic(remainder) number of elements.
        return ((distance + 1) * chunkCount) - remainder
      }
    }
    return distance * chunkCount
  }

  @inlinable
  internal func offsetBackward(
    _ i: Index, offsetBy distance: Int, limit: Index? = nil
  ) -> Index? {
    assert(distance < 0)
    let baseDistance =
      computeOffsetBackwardBaseDistance(i, distance)
    return makeOffsetIndex(
      from: i, baseBound: base.startIndex,
      distance: distance, baseDistance: baseDistance,
      limit: limit, by: <
    )
  }

  // Helper to compute index(offsetBy:) index.
  @inlinable
  internal func makeOffsetIndex(
    from i: Index, baseBound: Base.Index, distance: Int, baseDistance: Int,
    limit: Index?, by limitFn: (Base.Index, Base.Index) -> Bool
  ) -> Index? {
    let baseIdx = base.index(
      i.baseRange.lowerBound, offsetBy: baseDistance,
      limitedBy: baseBound
    )

    if let limit = limit {
      if baseIdx == nil {
        // If we past the bounds while advancing forward and the
        // limit is the `endIndex`, since the computation on base
        // don't take into account the remainder, we have to make
        // sure that passing the bound was because of the distance
        // not just because of a remainder. Special casing is less
        // expensive than always use count(which could be O(n) for
        // non-random access collection base) to compute the base
        // distance taking remainder into account.
        if baseDistance > 0 && limit == endIndex {
          if self.distance(from: i, to: limit) < distance {
            return nil
          }
        } else {
          return nil
        }
      }

      // Checks for the limit.
      let baseStartIdx = baseIdx ?? baseBound
      if limitFn(baseStartIdx, limit.baseRange.lowerBound) {
        return nil
      }
    }

    let baseStartIdx = baseIdx ?? baseBound
    let baseEndIdx =
      base.index(
        baseStartIdx, offsetBy: chunkCount, limitedBy: base.endIndex
      ) ?? base.endIndex

    return Index(_baseRange: baseStartIdx..<baseEndIdx)
  }
}

extension Collection {
  /// Returns a `ChunkedCollection<Self>` view presenting the elements
  /// in chunks with count of the given count parameter.
  ///
  /// - Parameter size: The size of the chunks. If the count parameter
  ///   is evenly divided by the count of the base `Collection` all the
  ///   chunks will have the count equals to size.
  ///   Otherwise, the last chunk will contain the remaining elements.
  ///
  ///     let c = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  ///     print(c.chunks(ofCount: 5).map(Array.init))
  ///     // [[1, 2, 3, 4, 5], [6, 7, 8, 9, 10]]
  ///
  ///     print(c.chunks(ofCount: 3).map(Array.init))
  ///     // [[1, 2, 3], [4, 5, 6], [7, 8, 9], [10]]
  ///
  /// - Complexity: O(*n*), because the start index is pre-computed.
  @inlinable
  public func chunks(ofCount count: Int) -> ChunkedByCount<Self> {
    precondition(count > 0, "Cannot chunk with count <= 0!")
    return ChunkedByCount(_base: self, _chunkCount: count)
  }
}

extension ChunkedByCount.Index: Hashable where Base.Index: Hashable {}

// Lazy conditional conformance.
extension ChunkedByCount: LazySequenceProtocol
where Base: LazySequenceProtocol {}
extension ChunkedByCount: LazyCollectionProtocol
where Base: LazyCollectionProtocol {}
