import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension LauncherModel {
    func installVCRuntime(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        runShell(
            title: "Install VC++ Runtime",
            command: "\(sourceConfig); \(config.gptkVCRunPath.shellQuoted) --prefix \(profile.prefix.shellQuoted)"
        )
    }

    func installDotNet6(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        runShell(
            title: "Install .NET 6 Desktop Runtime",
            command: "\(sourceConfig); \(config.gptkDotNet6Path.shellQuoted) --prefix \(profile.prefix.shellQuoted)"
        )
    }

    func installVCRuntimeGlobally() {
        runShell(
            title: "Install VC++ Runtime",
            command: "\(sourceConfig); \(config.gptkVCRunPath.shellQuoted) --all"
        )
    }

    func installStubs(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        runShell(
            title: "Install API Stubs",
            command: "\(sourceConfig); \(config.gptkStubsPath.shellQuoted) --prefix \(profile.prefix.shellQuoted)"
        )
    }

    func installStubsGlobally() {
        runShell(
            title: "Install API Stubs",
            command: "\(sourceConfig); \(config.gptkStubsPath.shellQuoted) --all"
        )
    }
}
