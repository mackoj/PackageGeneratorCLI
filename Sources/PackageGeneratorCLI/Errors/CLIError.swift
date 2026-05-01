import Foundation

enum CLIError: LocalizedError, Sendable {
  case fileNotFound(path: String)
  case directoryNotFound(path: String)
  case invalidJSON(file: String, reason: String)
  case parseFailure(file: String, reason: String)
  case ioError(path: String, reason: String)
  case invalidInput(reason: String)
  case writeFailure(path: String, reason: String)

  var errorDescription: String? {
    switch self {
    case .fileNotFound(let path):          return "File not found: \(path)"
    case .directoryNotFound(let path):     return "Directory not found: \(path)"
    case .invalidJSON(let file, let r):    return "Invalid JSON in \(file): \(r)"
    case .parseFailure(let file, let r):   return "Parse failure in \(file): \(r)"
    case .ioError(let path, let r):        return "I/O error at \(path): \(r)"
    case .invalidInput(let r):             return "Invalid input: \(r)"
    case .writeFailure(let path, let r):   return "Write failure at \(path): \(r)"
    }
  }
}
