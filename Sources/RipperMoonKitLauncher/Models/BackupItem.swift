import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct BackupItem: Identifiable, Hashable {
    let name: String
    let path: String
    let modified: Date

    var id: String { path }
}
