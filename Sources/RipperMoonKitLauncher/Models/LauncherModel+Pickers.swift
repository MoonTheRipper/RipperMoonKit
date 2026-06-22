import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension LauncherModel {
    func chooseFolder(current: String, assign: (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: current)
        if panel.runModal() == .OK, let url = panel.url {
            assign(url.path)
        }
    }

    func chooseExecutable(for profile: inout GameProfile) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: profile.gameFolder)
        if panel.runModal() == .OK, let url = panel.url {
            profile.gameFolder = url.deletingLastPathComponent().path
            profile.executable = url.lastPathComponent
            persistProfiles()
        }
    }

    func chooseIcon(for profile: inout GameProfile) {
        let panel = NSOpenPanel()
        panel.title = "Choose Game Icon"
        panel.prompt = "Use Icon"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.icns, .png, .jpeg, .tiff, .heic]
        if let iconPath = profile.iconPath, !iconPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: iconPath).deletingLastPathComponent()
        } else {
            panel.directoryURL = URL(fileURLWithPath: profile.gameFolder)
        }
        if panel.runModal() == .OK, let url = panel.url {
            profile.iconPath = url.path
            persistProfiles()
        }
    }

    func chooseControllerLayout(for profile: inout GameProfile) {
        let panel = NSOpenPanel()
        panel.title = "Choose Controller Layout"
        panel.prompt = "Use Layout"
        panel.message = "Pick a Steam Input controller config (.vdf) exported from Steam."
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        // .vdf has no registered UTType, so allow any file rather than filter it out.
        if let layoutPath = profile.controllerLayoutPath, !layoutPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: layoutPath).deletingLastPathComponent()
        } else {
            panel.directoryURL = URL(fileURLWithPath: profile.gameFolder)
        }
        if panel.runModal() == .OK, let url = panel.url {
            profile.controllerLayoutPath = url.path
            persistProfiles()
        }
    }
}
