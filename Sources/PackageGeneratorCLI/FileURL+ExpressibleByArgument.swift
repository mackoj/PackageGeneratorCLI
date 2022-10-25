import Foundation
import ArgumentParser

extension FileURL: ExpressibleByArgument {
  public init?(argument: String) {
    self.init(fileURLWithPath: argument)
  }
}
