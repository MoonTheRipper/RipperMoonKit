import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class LauncherModel: ObservableObject {
    @Published var config = ToolkitConfig.load()
    @Published var profiles: [GameProfile]
    @Published var pathSettings: PathSettings
    @Published var driveMaps: [DriveMap]
    @Published var toolkitSourceFolder: String
    @Published var isRunning = false
    @Published var guidedSetupRunning = false
    @Published var awaitingGPTKDownload = false
    @Published var setupDeferred = false
    @Published var pendingSelection: SidebarSelection?
    @Published var liveProfileIDs: Set<UUID> = []
    /// macOS PIDs backing each live profile — used to terminate games directly.
    var liveProfilePIDs: [UUID: [Int32]] = [:]
    @Published var commandOutput = ""
    @Published var lastResult = "Ready"
    @Published var backups: [BackupItem] = []
    @Published var removeConfigOnUninstall = false
    @Published var removePrefixesOnUninstall = false
    @Published var showSetupGuide = false
    @Published var tgdbAPIKeyLocal: String = ""
    @Published var pinnedProfileIDs: [UUID] = []
    @Published var updateNotice: UpdateNotice?
    @Published var isCheckingForUpdates = false

    let defaults = UserDefaults.standard
    let setupGuideSeenKey = "setupGuideSeen.v2"
    let tgdbAPIKeyDefaultsKey = "tgdbAPIKey"
    let pinnedProfilesKey = "pinnedProfiles.v1"
    var hasCheckedForUpdates = false
    var openedGPTKPageForCurrentSetup = false

    var defaultSelection: SidebarSelection {
        .library
    }

    var statusLine: String {
        config.exists ? "Config loaded from \(config.configPath)" : "Config not found at \(config.configPath)"
    }

    var toolkitSourceReady: Bool {
        FileManager.default.isExecutableFile(atPath: "\(toolkitSourceFolder)/install.zsh")
    }

    var steamProfile: GameProfile {
        profiles.first(where: { $0.isSteamApp }) ?? GameProfile.steam(config: config)
    }

    var steamInstallerPath: String {
        config.steamSetupPath
    }

    var steamInstallerReady: Bool {
        FileManager.default.fileExists(atPath: steamInstallerPath)
    }

    var steamInstallPendingPath: String {
        "\(config.gptkHome)/state/steam-install.pending"
    }

    var steamReady: Bool {
        steamExecutableExists(in: steamProfile)
    }

    var steamInstallPending: Bool {
        !steamReady && FileManager.default.fileExists(atPath: steamInstallPendingPath)
    }

    var setupChecks: [SetupCheck] {
        [
            SetupCheck(
                id: "source",
                title: "Toolkit files",
                explanation: "RipperMoonKit's own helper scripts, copied onto your Mac.",
                detail: toolkitSourceFolder,
                isOK: toolkitSourceReady,
                isOptional: false
            ),
            SetupCheck(
                id: "scripts",
                title: "Game launchers",
                explanation: "The commands RipperMoonKit uses to start your games.",
                detail: "\(config.gptkLaunchPath) and \(config.gptkSteamPath)",
                isOK: config.hasToolkitScripts,
                isOptional: false
            ),
            SetupCheck(
                id: "config",
                title: "Settings file",
                explanation: "Your personal config — storage folders and launch options.",
                detail: config.configPath,
                isOK: config.exists,
                isOptional: false
            ),
            SetupCheck(
                id: "wine",
                title: "Game Porting Toolkit runner",
                explanation: "The prebuilt Wine/GPTK app runner copied into the local toolkit folder.",
                detail: config.localGPTKWineHome,
                isOK: config.hasLocalWineRunner,
                isOptional: false
            ),
            SetupCheck(
                id: "d3dmetal",
                title: "D3DMetal graphics",
                explanation: "Apple's official GPTK runtime layer that renders DirectX games on Metal.",
                detail: config.gptkRuntime,
                isOK: config.hasLocalD3DMetalRuntime,
                isOptional: false
            ),
            SetupCheck(
                id: "steamsetup",
                title: "Steam installer",
                explanation: "The downloaded Steam setup file — only needed if you use Steam.",
                detail: steamInstallerPath,
                isOK: steamInstallerReady,
                isOptional: true
            ),
            SetupCheck(
                id: "steam",
                title: "Windows Steam",
                explanation: "Steam installed in its game prefix. Optional — skip it for non-Steam games.",
                detail: steamExecutablePath(in: steamProfile),
                isOK: steamReady,
                isOptional: true
            )
        ]
    }

    var nextSetupActionTitle: String {
        if !toolkitSourceReady { return "Prepare Source" }
        if !config.hasToolkitScripts || !config.exists { return "Install Toolkit" }
        if !config.hasLocalGPTK { return "Begin GPTK Install" }
        if !steamInstallerReady { return "Download Steam" }
        if steamInstallPending { return "Steam Installing" }
        if !steamReady { return "Install Steam" }
        return "Refresh Setup"
    }

    init() {
        let loaded = ToolkitConfig.load()
        config = loaded
        profiles = Self.loadProfiles(config: loaded, defaults: defaults)
        pathSettings = PathSettings(config: loaded)
        driveMaps = DriveMap.parse(loaded.values["GPTK_DRIVE_MAPS"] ?? "")
        let supportSource = Self.defaultToolkitSourceFolder(home: loaded.home)
        let desktopSource = "\(loaded.home)/Desktop/RipperMoonToolKit"
        if let storedSource = defaults.string(forKey: "toolkitSourceFolder") {
            let storedInstaller = "\(storedSource)/install.zsh"
            if storedSource == desktopSource && !FileManager.default.fileExists(atPath: storedInstaller) {
                toolkitSourceFolder = supportSource
            } else {
                toolkitSourceFolder = storedSource
            }
        } else {
            toolkitSourceFolder = supportSource
        }
        tgdbAPIKeyLocal = defaults.string(forKey: tgdbAPIKeyDefaultsKey)
            ?? (loaded.values["GPTK_TGDB_API_KEY"] ?? "")
        let validIDs = Set(profiles.map { $0.id })
        if let storedPins = defaults.array(forKey: pinnedProfilesKey) as? [String] {
            pinnedProfileIDs = storedPins.compactMap(UUID.init(uuidString:)).filter { validIDs.contains($0) }
        } else {
            // First run with pinning: seed with the first three profiles.
            pinnedProfileIDs = Array(profiles.prefix(3).map { $0.id })
        }
        refreshBackups()
        showSetupGuide = shouldShowSetupGuide(config: loaded)
        persistProfiles()
    }

    func reload() {
        persistProfiles()
        defaults.set(toolkitSourceFolder, forKey: "toolkitSourceFolder")
        config = ToolkitConfig.load()
        profiles = Self.repairProfiles(profiles, config: config)
        persistProfiles()
        pathSettings = PathSettings(config: config)
        driveMaps = DriveMap.parse(config.values["GPTK_DRIVE_MAPS"] ?? "")
        refreshBackups()
        guidedSetupRunning = false
        if config.hasLocalGPTK {
            awaitingGPTKDownload = false
            openedGPTKPageForCurrentSetup = false
        }
        // Surface the setup window when something is still missing; never
        // force it closed — if it is open and now complete it shows success.
        if (config.needsSetupGuide || !toolkitSourceReady) && !setupDeferred {
            showSetupGuide = true
        }
        lastResult = "Refreshed"
    }

    func profileBinding(id: UUID) -> Binding<GameProfile>? {
        guard profiles.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.profiles.first(where: { $0.id == id }) ?? GameProfile.empty(config: self.config) },
            set: { newValue in
                if let index = self.profiles.firstIndex(where: { $0.id == id }) {
                    self.profiles[index] = newValue
                    self.persistProfiles()
                }
            }
        )
    }

    func addProfile() -> GameProfile {
        let profile = GameProfile.empty(config: config)
        profiles.append(profile)
        persistProfiles()
        return profile
    }

    func deleteProfile(id: UUID) {
        if profiles.first(where: { $0.id == id })?.isRequiredLibraryProfile == true {
            lastResult = "Steam profile stays in the library"
            return
        }
        guard profiles.count > 1 else {
            lastResult = "At least one app profile is required"
            return
        }
        profiles.removeAll { $0.id == id }
        if pinnedProfileIDs.contains(id) {
            pinnedProfileIDs.removeAll { $0 == id }
            persistPins()
        }
        persistProfiles()
    }

    func persistProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: "gameProfiles.v1")
        }
    }
}
