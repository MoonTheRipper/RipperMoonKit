import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum SidebarSelection: Hashable {
    case library
    case profile(UUID)
    case backups
    case settings
}

let rmkAppVersion: String = resolvedRipperMoonKitVersion()

let rmkRepositoryURL = "https://github.com/MoonTheRipper/RipperMoonKit.git"

func resolvedRipperMoonKitVersion() -> String {
    let bundledVersion = Bundle.main.bundleURL
        .appendingPathComponent("Contents/Resources/toolkit/VERSION")
    if let raw = try? String(contentsOf: bundledVersion, encoding: .utf8) {
        let version = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !version.isEmpty { return version }
    }

    return (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
}

struct UpdateNotice: Identifiable, Equatable {
    let version: String
    let url: URL

    var id: String { version }
}

struct GitHubReleaseInfo: Decodable {
    let tagName: String
    let htmlURL: URL?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}

struct SetupCheck: Identifiable, Hashable {
    let id: String
    let title: String
    let explanation: String
    let detail: String
    let isOK: Bool
    let isOptional: Bool
}
