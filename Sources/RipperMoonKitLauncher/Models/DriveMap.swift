import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DriveMap: Codable, Identifiable, Hashable {
    var id = UUID()
    var letter: String
    var path: String

    init(letter: String, path: String) {
        self.letter = letter
        self.path = path
    }

    init?(line: String) {
        let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        letter = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        path = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parse(_ value: String) -> [DriveMap] {
        value.strippedShellQuotes
            .split(separator: ";")
            .compactMap { DriveMap(line: String($0)) }
    }
}
