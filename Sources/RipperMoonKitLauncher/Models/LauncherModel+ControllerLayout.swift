import AppKit
import SwiftUI

extension LauncherModel {
    /// Template file name the helper installs for a given app id.
    func controllerLayoutTemplateName(for profile: GameProfile) -> String {
        "rmk_app\(profile.controllerLayoutAppIDValue).vdf"
    }

    /// True when a RipperMoonKit-managed layout template is installed in the
    /// Steam prefix for this profile's target app id.
    func controllerLayoutApplied(for profile: GameProfile) -> Bool {
        let template = controllerLayoutTemplateName(for: profile)
        let path = "\(prefixPath(for: profile))/drive_c/Program Files (x86)/Steam/controller_base/templates/\(template)"
        return FileManager.default.fileExists(atPath: path)
    }

    /// Copy the chosen layout into the Steam prefix and assign it to the target
    /// app id via gptk-steam-layout. Steam must be stopped; the helper guards it.
    func applyControllerLayout(_ profile: GameProfile) {
        let profile = repairedProfile(profile)
        let layout = (profile.controllerLayoutPath ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !layout.isEmpty else {
            lastResult = "Pick a controller layout first"
            commandOutput = "No controller layout (.vdf) selected. Use the Layout picker, then Apply."
            return
        }
        let appID = profile.controllerLayoutAppIDValue
        runShell(
            title: "Apply controller layout (app \(appID))",
            command: "\(sourceConfig); \(config.gptkSteamLayoutPath.shellQuoted) apply --prefix \(profile.prefix.shellQuoted) --app-id \(appID.shellQuoted) --layout \(layout.shellQuoted)"
        )
    }

    /// Remove the layout selection and template for the target app id.
    func removeControllerLayout(_ profile: GameProfile) {
        let profile = repairedProfile(profile)
        let appID = profile.controllerLayoutAppIDValue
        runShell(
            title: "Remove controller layout (app \(appID))",
            command: "\(sourceConfig); \(config.gptkSteamLayoutPath.shellQuoted) remove --prefix \(profile.prefix.shellQuoted) --app-id \(appID.shellQuoted)"
        )
    }
}
