import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum WineRunner: String, Codable, CaseIterable, Hashable {
    case auto
    case gptk
    case staging
    case gptk4
    case custom

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .gptk: return "GPTK 3 (wine64 + D3DMetal)"
        case .staging: return "Wine Staging 11.8"
        case .gptk4: return "GPTK 4 (preview)"
        case .custom: return "Custom path"
        }
    }

    var summary: String {
        switch self {
        case .auto: return "Toolkit picks the best available runner for this profile."
        case .gptk: return "Best for 64-bit games. Required for D3DMetal. Blocked on macOS 27 for 32-bit binaries."
        case .staging: return "Use for 32-bit installers, Steam launching, .NET tools. No D3DMetal — renders via vkd3d/MoltenVK."
        case .gptk4: return "Apple GPTK 4 preview wine. Requires an installed GPTK 4 runner; falls back to GPTK 3 otherwise."
        case .custom: return "Use the Runner path below to point at any wine bundle."
        }
    }
}

struct GameProfile: Codable, Identifiable, Hashable {
    private static let eldenRingERSCID = UUID(uuidString: "00000000-0000-0000-0000-000000000480") ?? UUID()
    private static let steamClientID = UUID(uuidString: "00000000-0000-0000-0000-000000000481") ?? UUID()

    var id: UUID
    var name: String
    var prefix: String
    var gameFolder: String
    var executable: String
    var steamAppID: String?
    var iconPath: String?
    var runnerPath: String
    var winver: String
    var requiresSteam: Bool
    var noDXR: Bool
    var avx: Bool?
    var metalFX: Bool?
    var hud: Bool
    var noEsync: Bool
    var nativeWinmm: Bool
    var nativeSteamAPI: Bool
    var extraDllOverrides: String?
    var extraArguments: String
    var requiredFiles: [String]
    var systemImage: String
    var useModEngine: Bool?
    var modEngineFolder: String?
    var modEngineLauncher: String?
    var modEngineConfig: String?
    var modEngineLaunchBat: String?
    var randomizerExecutable: String?
    var seamlessDllPath: String?
    /// Optional so existing on-disk profiles decode cleanly. `nil` == `.auto` —
    /// preserve the legacy behavior of obeying `runnerPath` directly.
    var wineRunner: WineRunner?

    var effectiveWineRunner: WineRunner { wineRunner ?? .auto }

    // Steam Input controller layout assignment (Steam profile feature).
    // Defaulted optionals keep existing persisted profiles decodable.
    var controllerLayoutEnabled: Bool? = nil
    var controllerLayoutPath: String? = nil
    var controllerLayoutAppID: String? = nil

    /// The Steam app id a controller layout targets. Defaults to 480 (Spacewar,
    /// Valve's free Steamworks sample) when not set.
    var controllerLayoutAppIDValue: String {
        let trimmed = (controllerLayoutAppID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "480" : trimmed
    }

    var safeName: String {
        name.replacingOccurrences(of: "[^A-Za-z0-9._-]+", with: "-", options: .regularExpression)
    }

    var isEldenRingERSC: Bool {
        id == Self.eldenRingERSCID ||
            executable.localizedCaseInsensitiveContains("ersc_launcher.exe") ||
            name.localizedCaseInsensitiveContains("elden ring ersc")
    }

    var supportsModEngine: Bool {
        isEldenRingERSC || name.localizedCaseInsensitiveContains("elden ring")
    }

    var modEngineFolderPath: String {
        cleanOptional(modEngineFolder, fallback: "ModEngine2")
    }

    var modEngineLauncherName: String {
        cleanOptional(modEngineLauncher, fallback: "modengine2_launcher.exe")
    }

    var modEngineConfigName: String {
        cleanOptional(modEngineConfig, fallback: "config_eldenring.toml")
    }

    var modEngineLaunchBatName: String {
        cleanOptional(modEngineLaunchBat, fallback: "launchmod_eldenring.bat")
    }

    var randomizerExecutablePath: String {
        cleanOptional(randomizerExecutable, fallback: "randomizer/EldenRingRandomizer.exe")
    }

    var seamlessDllConfigPath: String {
        cleanOptional(seamlessDllPath, fallback: "../SeamlessCoop/ersc.dll")
    }

    var isSteamApp: Bool {
        id == Self.steamClientID || (name == "Steam" && prefix == "Steam" && steamAppID == nil)
    }

    var isSteamLibraryGame: Bool {
        !(steamAppID ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSteamApp
    }

    var isSteamManaged: Bool {
        isSteamApp || isSteamLibraryGame
    }

    var isGodOfWarRagnarok: Bool {
        prefix.localizedCaseInsensitiveCompare("GOWR") == .orderedSame ||
            executable.localizedCaseInsensitiveContains("gowr.exe") ||
            name.localizedCaseInsensitiveContains("god of war ragnarok") ||
            name.localizedCaseInsensitiveContains("god of war ragnarök")
    }

    var isRequiredLibraryProfile: Bool {
        isSteamApp
    }

    /// Profiles whose prefix should get the DirectSound no-capture proxy applied
    /// (ERSC Golden Pot voice-capture freeze; GoWR previously rode the same runner).
    var needsVoiceCaptureFix: Bool {
        isEldenRingERSC || isGodOfWarRagnarok
    }

    func repairedForCurrentToolkit(config: ToolkitConfig) -> GameProfile {
        if isSteamApp {
            var repaired = self
            repaired.id = Self.steamClientID
            repaired.name = "Steam"
            repaired.prefix = "Steam"
            repaired.gameFolder = "\(config.prefixRoot)/Steam"
            repaired.executable = "steam.exe"
            repaired.steamAppID = nil
            repaired.requiresSteam = false
            repaired.requiredFiles = []
            repaired.systemImage = "square.grid.2x2.fill"
            return repaired
        }

        if isGodOfWarRagnarok {
            var repaired = self

            repaired.prefix = "GOWR"
            repaired.executable = repaired.executable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "GoWR.exe" : repaired.executable
            repaired.winver = "win10"
            repaired.requiresSteam = false
            repaired.noDXR = true
            repaired.noEsync = true
            repaired.avx = true
            repaired.metalFX = true
            repaired.nativeWinmm = false
            repaired.nativeSteamAPI = false
            repaired.systemImage = repaired.systemImage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "app.fill" : repaired.systemImage

            // The no-capture runner was retired; the fix now lives in the prefix.
            // Clear any stale runner pointer so GoWR uses the stock GPTK runner.
            if repaired.runnerPath.contains("runners/gptk-dsound-nocap") {
                repaired.runnerPath = ""
            }

            let gameInputOverride = "GameInput=n"
            let currentOverride = repaired.extraDllOverrides?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let hasGameInputOverride = currentOverride
                .split(separator: ";")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .contains(gameInputOverride.lowercased())
            if !hasGameInputOverride {
                repaired.extraDllOverrides = currentOverride.isEmpty ? gameInputOverride : "\(currentOverride);\(gameInputOverride)"
            }

            return repaired
        }

        guard isEldenRingERSC else { return self }

        var repaired = self

        repaired.prefix = repaired.prefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Steam" : repaired.prefix
        repaired.executable = "ersc_launcher.exe"
        repaired.winver = repaired.winver.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "win10" : repaired.winver
        repaired.requiresSteam = true
        repaired.noDXR = true
        repaired.noEsync = true
        repaired.nativeWinmm = true
        repaired.nativeSteamAPI = true
        repaired.systemImage = "gamecontroller.fill"
        repaired.modEngineFolder = repaired.modEngineFolder ?? "ModEngine2"
        repaired.modEngineLauncher = repaired.modEngineLauncher ?? "modengine2_launcher.exe"
        repaired.modEngineConfig = repaired.modEngineConfig ?? "config_eldenring.toml"
        repaired.modEngineLaunchBat = repaired.modEngineLaunchBat ?? "launchmod_eldenring.bat"
        repaired.randomizerExecutable = repaired.randomizerExecutable ?? "randomizer/EldenRingRandomizer.exe"
        repaired.seamlessDllPath = repaired.seamlessDllPath ?? "../SeamlessCoop/ersc.dll"

        for required in ["eldenring.exe", "SeamlessCoop"] where !repaired.requiredFiles.contains(required) {
            repaired.requiredFiles.append(required)
        }

        // The no-capture runner was retired; the fix now lives in the prefix
        // (gptk-dsound-nocap). Clear any stale runner pointer so ERSC uses the
        // stock GPTK runner.
        if repaired.runnerPath.contains("runners/gptk-dsound-nocap") {
            repaired.runnerPath = ""
        }

        return repaired
    }

    static func eldenRing(config: ToolkitConfig, defaults: UserDefaults) -> GameProfile {
        GameProfile(
            id: eldenRingERSCID,
            name: "Elden Ring ERSC",
            prefix: defaults.string(forKey: "prefix") ?? "Steam",
            gameFolder: defaults.string(forKey: "gameFolder") ?? "\(config.externalRoot)/Games/EldenRing/Game",
            executable: "ersc_launcher.exe",
            steamAppID: nil,
            iconPath: defaults.string(forKey: "iconPath"),
            runnerPath: defaults.string(forKey: "runnerPath") ?? "",
            winver: defaults.string(forKey: "winver") ?? "win10",
            requiresSteam: true,
            noDXR: defaults.object(forKey: "noDXR") as? Bool ?? true,
            avx: nil,
            metalFX: false,
            hud: defaults.object(forKey: "hud") as? Bool ?? false,
            noEsync: defaults.object(forKey: "noEsync") as? Bool ?? true,
            nativeWinmm: defaults.object(forKey: "nativeWinmm") as? Bool ?? true,
            nativeSteamAPI: defaults.object(forKey: "nativeSteamAPI") as? Bool ?? true,
            extraDllOverrides: nil,
            extraArguments: "",
            requiredFiles: ["eldenring.exe", "SeamlessCoop"],
            systemImage: "gamecontroller.fill",
            useModEngine: false,
            modEngineFolder: "ModEngine2",
            modEngineLauncher: "modengine2_launcher.exe",
            modEngineConfig: "config_eldenring.toml",
            modEngineLaunchBat: "launchmod_eldenring.bat",
            randomizerExecutable: "randomizer/EldenRingRandomizer.exe",
            seamlessDllPath: "../SeamlessCoop/ersc.dll"
        )
    }

    static func empty(config: ToolkitConfig) -> GameProfile {
        GameProfile(
            id: UUID(),
            name: "New App",
            prefix: "MyGame",
            gameFolder: "\(config.externalRoot)/Games",
            executable: "Game.exe",
            steamAppID: nil,
            iconPath: nil,
            runnerPath: "",
            winver: "win10",
            requiresSteam: false,
            noDXR: false,
            avx: nil,
            metalFX: false,
            hud: false,
            noEsync: false,
            nativeWinmm: false,
            nativeSteamAPI: false,
            extraDllOverrides: nil,
            extraArguments: "",
            requiredFiles: [],
            systemImage: "app.fill",
            useModEngine: false,
            modEngineFolder: nil,
            modEngineLauncher: nil,
            modEngineConfig: nil,
            modEngineLaunchBat: nil,
            randomizerExecutable: nil,
            seamlessDllPath: nil
        )
    }

    static func steam(config: ToolkitConfig) -> GameProfile {
        GameProfile(
            id: steamClientID,
            name: "Steam",
            prefix: "Steam",
            gameFolder: "\(config.prefixRoot)/Steam",
            executable: "steam.exe",
            steamAppID: nil,
            iconPath: nil,
            runnerPath: "",
            winver: "win10",
            requiresSteam: false,
            noDXR: false,
            avx: nil,
            metalFX: false,
            hud: false,
            noEsync: false,
            nativeWinmm: false,
            nativeSteamAPI: false,
            extraDllOverrides: nil,
            extraArguments: "",
            requiredFiles: [],
            systemImage: "square.grid.2x2.fill",
            useModEngine: false,
            modEngineFolder: nil,
            modEngineLauncher: nil,
            modEngineConfig: nil,
            modEngineLaunchBat: nil,
            randomizerExecutable: nil,
            seamlessDllPath: nil
        )
    }

    static func steamGame(appID: String, name: String, installDir: String, config: ToolkitConfig) -> GameProfile {
        GameProfile(
            id: UUID(),
            name: name,
            prefix: "Steam",
            gameFolder: "\(config.steamLibrary)/steamapps/common/\(installDir)",
            executable: "",
            steamAppID: appID,
            iconPath: nil,
            runnerPath: "",
            winver: "win10",
            requiresSteam: true,
            noDXR: false,
            avx: nil,
            metalFX: false,
            hud: false,
            noEsync: false,
            nativeWinmm: false,
            nativeSteamAPI: false,
            extraDllOverrides: nil,
            extraArguments: "",
            requiredFiles: [],
            systemImage: "gamecontroller.fill",
            useModEngine: false,
            modEngineFolder: nil,
            modEngineLauncher: nil,
            modEngineConfig: nil,
            modEngineLaunchBat: nil,
            randomizerExecutable: nil,
            seamlessDllPath: nil
        )
    }

    private func cleanOptional(_ value: String?, fallback: String) -> String {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
