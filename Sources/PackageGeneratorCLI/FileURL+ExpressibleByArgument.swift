import Foundation
import ArgumentParser

extension FileURL: @retroactive ExpressibleByArgument {
  public init?(argument: String) {
    self.init(fileURLWithPath: argument)
  }
}
