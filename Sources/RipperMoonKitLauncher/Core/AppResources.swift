import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum AppResource {
    private static let resourceBundleName = "RipperMoonKit_RipperMoonKitLauncher.bundle"

    static func image(named name: String, extension ext: String = "png") -> NSImage? {
        guard let url = url(forResource: name, withExtension: ext) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    static func url(forResource name: String, withExtension ext: String) -> URL? {
        let fileName = "\(name).\(ext)"
        let candidates: [URL?] = [
            Bundle.main.resourceURL?
                .appendingPathComponent(resourceBundleName)
                .appendingPathComponent(fileName),
            Bundle.main.resourceURL?
                .appendingPathComponent(fileName),
            Bundle.main.bundleURL
                .deletingLastPathComponent()
                .appendingPathComponent(resourceBundleName)
                .appendingPathComponent(fileName),
            Bundle.main.bundleURL
                .appendingPathComponent(resourceBundleName)
                .appendingPathComponent(fileName)
        ]

        return candidates.compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
