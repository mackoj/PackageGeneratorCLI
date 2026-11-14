import Foundation

public struct PackageInformation: Codable, Sendable {
  public struct PathInfo: Codable, Sendable {
    public let path: String
    public let name: String
    public let exclude: [String]?

    enum CodingKeys: String, CodingKey {
      case path
      case name
      case exclude
    }
  }
  public let test: PathInfo?
  public let target: PathInfo
  
  public init(from decoder: any Decoder) throws {
    // The current format, an object, is tried first: a failed decode builds an error, and most entries are objects.
    let container: KeyedDecodingContainer<CodingKeys>
    do {
      container = try decoder.container(keyedBy: CodingKeys.self)
    } catch {
      // Legacy format: a bare path string.
      guard let pathString = try? decoder.singleValueContainer().decode(String.self) else { throw error }
      let path = URL(fileURLWithPath: pathString)
      self.target = PathInfo(path: pathString, name: path.lastPathComponent, exclude: nil)
      self.test = nil
      return
    }
    self.test = try container.decodeIfPresent(PackageInformation.PathInfo.self, forKey: .test)
    self.target = try container.decode(PackageInformation.PathInfo.self, forKey: .target)
  }
}
