/// Where the import declarations of a Swift file can be, found without parsing it.
///
/// Every import declaration contains the keyword `import`, so none starts after the last occurrence of that word.
/// Parsing only up to the end of that declaration gives the parser a fraction of a typical file, whose imports
/// sit at the top, and yields the same imports as parsing the whole file.
enum ImportRegion {
  /// The number of leading bytes that hold every import declaration in `source`: 0 when the word `import` does not
  /// occur, `source.count` when the end of the last declaration cannot be found safely.
  static func length(of source: UnsafeBufferPointer<UInt8>) -> Int {
    guard let keyword = lastImportKeyword(in: source) else { return 0 }
    var position = keyword + importWord.count
    var end = position
    var expectsComponent = true
    // The rest of the declaration: an optional kind (`struct`, `func`…) and a dotted path, with trivia between.
    while true {
      guard let next = skipTrivia(in: source, from: position) else { return source.count }
      position = next
      guard position < source.count else { return source.count }
      let byte = source[position]
      if expectsComponent, let wordEnd = identifierEnd(in: source, from: position) {
        let isKind = importKinds.contains(where: { $0.elementsEqual(source[position..<wordEnd]) })
        position = wordEnd
        end = wordEnd
        expectsComponent = isKind
      } else if !expectsComponent, byte == UInt8(ascii: ".") {
        position += 1
        expectsComponent = true
      } else {
        break
      }
    }
    // Finish the declaration's last line.
    while end < source.count, source[end] != UInt8(ascii: "\n") { end += 1 }
    return end
  }

  private static let importWord = Array("import".utf8)
  private static let importKinds: [[UInt8]] = ["typealias", "struct", "class", "enum", "protocol", "let", "var", "func"]
    .map { Array($0.utf8) }

  /// The offset of the last `import` that is a whole word.
  private static func lastImportKeyword(in source: UnsafeBufferPointer<UInt8>) -> Int? {
    let count = importWord.count
    guard source.count >= count else { return nil }
    var index = source.count - count
    while index >= 0 {
      if source[index] == UInt8(ascii: "i"),
        source[index + 1] == UInt8(ascii: "m"), source[index + 2] == UInt8(ascii: "p"),
        source[index + 3] == UInt8(ascii: "o"), source[index + 4] == UInt8(ascii: "r"),
        source[index + 5] == UInt8(ascii: "t"),
        index == 0 || !isIdentifierByte(source[index - 1]),
        index + count == source.count || !isIdentifierByte(source[index + count])
      {
        return index
      }
      index -= 1
    }
    return nil
  }

  /// The offset after whitespace and comments, or nil inside an unterminated block comment.
  private static func skipTrivia(in source: UnsafeBufferPointer<UInt8>, from start: Int) -> Int? {
    var position = start
    while position < source.count {
      let byte = source[position]
      if byte == UInt8(ascii: " ") || byte == UInt8(ascii: "\t") || byte == UInt8(ascii: "\n")
        || byte == UInt8(ascii: "\r")
      {
        position += 1
      } else if byte == UInt8(ascii: "/"), position + 1 < source.count, source[position + 1] == UInt8(ascii: "/") {
        while position < source.count, source[position] != UInt8(ascii: "\n") { position += 1 }
      } else if byte == UInt8(ascii: "/"), position + 1 < source.count, source[position + 1] == UInt8(ascii: "*") {
        // Block comments nest in Swift.
        var depth = 0
        repeat {
          guard position + 1 < source.count else { return nil }
          if source[position] == UInt8(ascii: "/"), source[position + 1] == UInt8(ascii: "*") {
            depth += 1
            position += 2
          } else if source[position] == UInt8(ascii: "*"), source[position + 1] == UInt8(ascii: "/") {
            depth -= 1
            position += 2
          } else {
            position += 1
          }
        } while depth > 0
      } else {
        break
      }
    }
    return position
  }

  /// The end of the identifier at `start`, plain or in backticks, or nil when none starts there.
  private static func identifierEnd(in source: UnsafeBufferPointer<UInt8>, from start: Int) -> Int? {
    if source[start] == UInt8(ascii: "`") {
      var position = start + 1
      while position < source.count, source[position] != UInt8(ascii: "`"), source[position] != UInt8(ascii: "\n") {
        position += 1
      }
      return position < source.count && source[position] == UInt8(ascii: "`") ? position + 1 : nil
    }
    guard isIdentifierByte(source[start]) else { return nil }
    var position = start
    while position < source.count, isIdentifierByte(source[position]) { position += 1 }
    return position
  }

  /// ASCII letters, digits and `_`, and every non-ASCII byte (identifiers may be Unicode).
  private static func isIdentifierByte(_ byte: UInt8) -> Bool {
    switch byte {
    case UInt8(ascii: "a")...UInt8(ascii: "z"), UInt8(ascii: "A")...UInt8(ascii: "Z"),
      UInt8(ascii: "0")...UInt8(ascii: "9"), UInt8(ascii: "_"), 0x80...:
      return true
    default:
      return false
    }
  }
}
