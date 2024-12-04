import Foundation

public struct ParsedPackage: Codable, CustomStringConvertible {
  public enum Target: Codable {
    case bin
    case test
    case product
  }
  public var target: Target? = nil
  public var name: String
  public var isProduct: Bool {
    switch target {
      case .product: return true
      default: return false
    }
  }
  public var isTest: Bool {
    switch target {
      case .test: return true
      default: return false
    }
  }
  public var isBin: Bool {
    switch target {
      case .bin: return true
      default: return false
    }
  }

  public var dependencies: [String]
  public var path: String
  public var fullPath: String
  public var resources: String?
  public var localDependencies: Int = 0
  public var hasBiggestNumberOfDependencies: Bool = false

  public var hasResources: Bool {
    resources != nil && resources!.isEmpty == false
  }

  public var description: String {
    return "[\(dependencies.count)|\(localDependencies)] \(name) \(hasResources == false ? "" : "/ hasResources")"
  }
  
  public init(name: String, dependencies: [String], path: String, fullPath: String, resources: String? = nil, localDependencies: Int = 0, hasBiggestNumberOfDependencies: Bool = false, target: Target) {
    self.name = name
    self.dependencies = dependencies
    self.path = path
    self.fullPath = fullPath
    self.resources = resources
    self.localDependencies = localDependencies
    self.hasBiggestNumberOfDependencies = hasBiggestNumberOfDependencies
  }
}
