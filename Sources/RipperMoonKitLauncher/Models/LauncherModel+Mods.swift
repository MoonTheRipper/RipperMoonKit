import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension LauncherModel {
    func installModEngineRandomizerProfile(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        let sourceScript = "\(toolkitSourceFolder)/scripts/install-elden-mod-pack.zsh"
        let installedScript = "\(config.gptkHome)/scripts/install-elden-mod-pack.zsh"
        let toolsPrefix = toolPrefixName(for: profile)
        let toolEnv = toolRunnerEnvAssignment()
        runShell(
            title: "Install ModEngine + Randomizer",
            command: "\(sourceConfig); env \(toolEnv) \(config.gptkDotNet6Path.shellQuoted) --prefix \(toolsPrefix.shellQuoted); if [[ -x \(sourceScript.shellQuoted) ]]; then script=\(sourceScript.shellQuoted); else script=\(installedScript.shellQuoted); fi; zsh \"$script\" --game-dir \(profile.gameFolder.shellQuoted) --open-download-pages",
            completion: { [weak self] in self?.reload() }
        )
    }

    func backupEldenModState(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        let sourceScript = "\(toolkitSourceFolder)/scripts/elden-mod-state.zsh"
        let installedScript = "\(config.gptkHome)/scripts/elden-mod-state.zsh"
        runShell(
            title: "Backup Elden Ring Mod State",
            command: "\(sourceConfig); if [[ -x \(sourceScript.shellQuoted) ]]; then script=\(sourceScript.shellQuoted); else script=\(installedScript.shellQuoted); fi; zsh \"$script\" backup --game-dir \(profile.gameFolder.shellQuoted)"
        )
    }

    func importFriendKit(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        let panel = NSOpenPanel()
        panel.title = "Choose Friend Kit Folder Or ZIP"
        panel.prompt = "Import Friend Kit"
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "zip") ?? .zip]
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let sourceScript = "\(toolkitSourceFolder)/scripts/elden-mod-state.zsh"
        let installedScript = "\(config.gptkHome)/scripts/elden-mod-state.zsh"
        let toolsPrefix = toolPrefixName(for: profile)
        let toolEnv = toolRunnerEnvAssignment()
        runShell(
            title: "Import Friend Kit",
            command: "\(sourceConfig); env \(toolEnv) \(config.gptkDotNet6Path.shellQuoted) --prefix \(toolsPrefix.shellQuoted); if [[ -x \(sourceScript.shellQuoted) ]]; then script=\(sourceScript.shellQuoted); else script=\(installedScript.shellQuoted); fi; zsh \"$script\" import-friend --game-dir \(profile.gameFolder.shellQuoted) --friend-kit \(url.path.shellQuoted) --force",
            completion: { [weak self] in self?.reload() }
        )
    }

    func installModZips(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        let panel = NSOpenPanel()
        panel.title = "Choose ModEngine, Randomizer, Seamless Coop, Or Anti Cheat ZIPs"
        panel.prompt = "Install Zips"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [UTType(filenameExtension: "zip") ?? .zip]
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

        guard panel.runModal() == .OK else { return }
        let paths = panel.urls.map(\.path)
        guard !paths.isEmpty else { return }

        runShell(
            title: "Install Mod Zips",
            command: modZipInstallCommand(for: profile, zipPaths: paths)
        )
    }

    func prepareModEngine(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        do {
            let modEngineDir = modEngineDirectory(for: profile)
            try FileManager.default.createDirectory(atPath: modEngineDir, withIntermediateDirectories: true)
            try writeModEngineConfig(for: profile)
            try writeModEngineLaunchBat(for: profile)
            lastResult = "Prepared ModEngine files"
            commandOutput = """
            Wrote:
            \(modEngineConfigPath(for: profile))
            \(modEngineLaunchBatPath(for: profile))

            Open the randomizer, import the .randomizeopt file, click Randomize, then launch the modded profile.
            """
        } catch {
            lastResult = "ModEngine prep failed"
            commandOutput = error.localizedDescription
        }
    }

    func modZipInstallCommand(for profile: GameProfile, zipPaths: [String]) -> String {
        let zipList = zipPaths.map(\.shellQuoted).joined(separator: " ")
        return """
        \(sourceConfig)
        game=\(profile.gameFolder.shellQuoted)
        modengine=\(modEngineDirectory(for: profile).shellQuoted)
        stamp="$(date +%Y%m%d-%H%M%S)"
        cleanup_mac_sidecars() {
          local path="$1"
          [[ -d "$path" ]] || return 0
          find "$path" \\( -name '._*' -o -name '.DS_Store' -o -name '__MACOSX' \\) -exec rm -rf {} + 2>/dev/null || true
        }
        mkdir -p "$modengine"
        for zip in \(zipList); do
          echo "Inspecting $zip"
          entries="$(unzip -Z1 "$zip" 2>/dev/null || true)"
          if print -r -- "$entries" | grep -qi 'modengine2_launcher.exe'; then
            echo "Installing ModEngine 2"
            unzip -oq "$zip" -d "$modengine"
            cleanup_mac_sidecars "$modengine"
            if [[ ! -f "$modengine/modengine2_launcher.exe" ]]; then
              root="$(find "$modengine" -mindepth 1 -maxdepth 1 -type d -print | head -n 1)"
              if [[ -n "$root" && -f "$root/modengine2_launcher.exe" ]]; then
                find "$root" -mindepth 1 -maxdepth 1 -exec mv -f {} "$modengine/" \\;
                rmdir "$root" 2>/dev/null || true
              fi
            fi
            cleanup_mac_sidecars "$modengine"
          elif print -r -- "$entries" | grep -qi 'EldenRingRandomizer.exe'; then
            echo "Installing Item and Enemy Randomizer"
            target="$modengine/randomizer"
            tmp="$modengine/.randomizer-install-$stamp"
            [[ -d "$target" ]] && mv "$target" "$target.$stamp.backup"
            rm -rf "$tmp"
            mkdir -p "$tmp"
            unzip -oq "$zip" -d "$tmp"
            cleanup_mac_sidecars "$tmp"
            root="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d -print | head -n 1)"
            if [[ -n "$root" && -f "$root/EldenRingRandomizer.exe" ]]; then
              mv "$root" "$target"
            else
              mkdir -p "$target"
              find "$tmp" -mindepth 1 -maxdepth 1 -exec mv -f {} "$target/" \\;
            fi
            rm -rf "$tmp"
            cleanup_mac_sidecars "$target"
          elif print -r -- "$entries" | grep -qi 'ersc_launcher.exe'; then
            echo "Installing Seamless Coop"
            keep="$(mktemp -t ersc-settings.XXXXXX)"
            [[ -f "$game/SeamlessCoop/ersc_settings.ini" ]] && cp "$game/SeamlessCoop/ersc_settings.ini" "$keep"
            unzip -oq "$zip" -d "$game"
            cleanup_mac_sidecars "$game/SeamlessCoop"
            [[ -s "$keep" ]] && mkdir -p "$game/SeamlessCoop" && cp "$keep" "$game/SeamlessCoop/ersc_settings.ini"
            rm -f "$keep"
          elif print -r -- "$entries" | grep -qi 'toggle_anti_cheat.exe'; then
            echo "Installing Anti Cheat Toggler"
            unzip -oq "$zip" -d "$game"
            cleanup_mac_sidecars "$game"
          else
            echo "Skipped unrecognized zip: $zip"
          fi
        done
        echo "Mod zip install finished."
        """
    }

    func modEngineValidationItems(for profile: GameProfile) -> [ValidationItem] {
        [
            ValidationItem(title: "eldenring.exe", isOK: FileManager.default.fileExists(atPath: "\(profile.gameFolder)/eldenring.exe")),
            ValidationItem(title: profile.modEngineLauncherName, isOK: FileManager.default.fileExists(atPath: modEngineLauncherPath(for: profile))),
            ValidationItem(title: profile.modEngineConfigName, isOK: FileManager.default.fileExists(atPath: modEngineConfigPath(for: profile))),
            ValidationItem(title: profile.modEngineLaunchBatName, isOK: FileManager.default.fileExists(atPath: modEngineLaunchBatPath(for: profile))),
            ValidationItem(title: profile.randomizerExecutablePath, isOK: FileManager.default.fileExists(atPath: randomizerExecutablePath(for: profile))),
            ValidationItem(title: profile.seamlessDllConfigPath, isOK: FileManager.default.fileExists(atPath: URL(fileURLWithPath: modEngineDirectory(for: profile)).appendingPathComponent(profile.seamlessDllConfigPath).standardized.path))
        ]
    }

    func modEngineDirectory(for profile: GameProfile) -> String {
        resolvedProfilePath(profile.modEngineFolderPath, in: profile.gameFolder)
    }

    func profileRelativePath(_ path: String, from gameFolder: String) -> String {
        let folder = URL(fileURLWithPath: gameFolder).standardized.path
        let selected = URL(fileURLWithPath: path).standardized.path
        if selected == folder {
            return "."
        }
        if selected.hasPrefix(folder + "/") {
            return String(selected.dropFirst(folder.count + 1))
        }
        return selected
    }

    func modEngineLauncherPath(for profile: GameProfile) -> String {
        URL(fileURLWithPath: modEngineDirectory(for: profile)).appendingPathComponent(profile.modEngineLauncherName).path
    }

    func modEngineConfigPath(for profile: GameProfile) -> String {
        URL(fileURLWithPath: modEngineDirectory(for: profile)).appendingPathComponent(profile.modEngineConfigName).path
    }

    func modEngineLaunchBatPath(for profile: GameProfile) -> String {
        URL(fileURLWithPath: modEngineDirectory(for: profile)).appendingPathComponent(profile.modEngineLaunchBatName).path
    }

    func randomizerExecutablePath(for profile: GameProfile) -> String {
        URL(fileURLWithPath: modEngineDirectory(for: profile)).appendingPathComponent(profile.randomizerExecutablePath).path
    }

    func writeModEngineConfig(for profile: GameProfile) throws {
        let configPath = modEngineConfigPath(for: profile)
        try backupFileIfPresent(configPath)
        let text = """
        [modengine]
        debug = false

        external_dlls = [
            "\(profile.seamlessDllConfigPath.tomlEscaped)"
        ]

        [extension.mod_loader]
        enabled = true
        loose_params = false

        mods = [
            { enabled = true, name = "default", path = "mod" },
            { enabled = true, name = "randomizer", path = "randomizer" }
        ]

        [extension.scylla_hide]
        enabled = false
        """
        try text.write(toFile: configPath, atomically: true, encoding: .utf8)
    }

    func writeModEngineLaunchBat(for profile: GameProfile) throws {
        let batPath = modEngineLaunchBatPath(for: profile)
        try backupFileIfPresent(batPath)
        let gameExe = winePath(forMacPath: "\(profile.gameFolder)/eldenring.exe")
        let text = """
        @echo off
        chcp 65001
        .\\\(profile.modEngineLauncherName) -t er -c .\\\(profile.modEngineConfigName) --game-path "\(gameExe)"
        """
        try text.write(toFile: batPath, atomically: true, encoding: .utf8)
    }

    func backupFileIfPresent(_ path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else { return }
        let stamp = DateFormatter.backupStamp.string(from: Date())
        let backup = "\(path).\(stamp).bak"
        if !FileManager.default.fileExists(atPath: backup) {
            try FileManager.default.copyItem(atPath: path, toPath: backup)
        }
    }

    func resolvedProfilePath(_ path: String, in gameFolder: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "." else { return gameFolder }
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
            return NSString(string: trimmed).expandingTildeInPath
        }
        return URL(fileURLWithPath: gameFolder).appendingPathComponent(trimmed).standardized.path
    }

    func winePath(forMacPath path: String) -> String {
        let standardized = URL(fileURLWithPath: path).standardized.path
        let withoutLeadingSlash = standardized.hasPrefix("/") ? String(standardized.dropFirst()) : standardized
        return "Z:\\\(withoutLeadingSlash.replacingOccurrences(of: "/", with: "\\"))"
    }
}
