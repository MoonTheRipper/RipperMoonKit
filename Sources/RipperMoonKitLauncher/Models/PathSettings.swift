import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PathSettings: Hashable {
    var gptkHome: String
    var prefixRoot: String
    var gamesRoot: String
    var externalRoot: String
    var steamLibrary: String

    init(config: ToolkitConfig) {
        gptkHome = config.gptkHome
        prefixRoot = config.prefixRoot
        gamesRoot = config.gamesRoot
        externalRoot = config.externalRoot
        steamLibrary = config.steamLibrary
    }
}
