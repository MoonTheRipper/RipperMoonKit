import AppKit
import SwiftUI
import UniformTypeIdentifiers

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

    var isRequiredLibraryProfile: Bool {
        isSteamApp
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

        guard isEldenRingERSC else { return self }

        var repaired = self
        let patchedRunner = "\(config.gptkHome)/runners/gptk-dsound-nocap-20260513"
        let patchedRunnerExists = FileManager.default.isExecutableFile(atPath: "\(patchedRunner)/bin/wine64")
        let stockRunnerPaths = [
            config.gptkWineHome,
            "\(config.gptkHome)/apps/Game Porting Toolkit.app/Contents/Resources/wine",
            "/Applications/Game Porting Toolkit.app/Contents/Resources/wine"
        ]

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

        let runner = repaired.runnerPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let runnerMissing = runner.isEmpty || !FileManager.default.isExecutableFile(atPath: "\(runner)/bin/wine64")
        let runnerIsStock = stockRunnerPaths.contains(runner)
        if patchedRunnerExists, runnerMissing || runnerIsStock {
            repaired.runnerPath = patchedRunner
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
            runnerPath: defaults.string(forKey: "runnerPath") ?? "\(config.gptkHome)/runners/gptk-dsound-nocap-20260513",
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
