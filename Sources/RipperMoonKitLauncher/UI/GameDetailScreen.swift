import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Game Detail

enum GameTab: String, CaseIterable {
    case app = "App", mods = "Mods", launch = "Launch", commands = "Commands"
    var icon: String {
        switch self {
        case .app: return "gamecontroller.fill"
        case .mods: return "square.3.layers.3d"
        case .launch: return "play.fill"
        case .commands: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

struct GameDetailScreen: View {
    @EnvironmentObject private var model: LauncherModel
    @Binding var profile: GameProfile
    @Binding var selection: SidebarSelection
    @State private var tab: GameTab = .app
    @State private var confirmDelete = false
    @State private var showCoverSearch = false

    private var tabs: [GameTab] {
        profile.supportsModEngine ? GameTab.allCases : [.app, .launch, .commands]
    }

    var body: some View {
        VStack(spacing: 0) {
            hero
            tabBar
            VStack(alignment: .leading, spacing: 14) {
                switch tab {
                case .app:      appTab
                case .mods:     ModsTab(profile: $profile)
                case .launch:   launchTab
                case .commands: commandsTab
                }
            }
            .padding(EdgeInsets(top: 18, leading: 24, bottom: 36, trailing: 24))
        }
        .onChange(of: profile) { _, _ in model.persistProfiles() }
        .sheet(isPresented: $showCoverSearch) {
            CoverSearchSheet(profile: $profile)
                .environmentObject(model)
                .frame(width: 580, height: 560)
        }
        .confirmationDialog("Delete this app profile?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                model.deleteProfile(id: profile.id)
                selection = .library
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // ── Hero ──────────────────────────────────────────────────────────────
    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            CoverArt(iconPath: profile.iconPath, label: profile.name,
                     seed: coverSeed(profile.name), corner: 0, showLabel: false)
            LinearGradient(colors: [.clear, Onyx.bg], startPoint: .top, endPoint: .bottom)
            HStack(alignment: .bottom, spacing: 18) {
                CoverArt(iconPath: profile.iconPath, label: profile.name,
                         seed: coverSeed(profile.name), corner: 18)
                    .frame(width: 92, height: 92)
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 9) {
                        Text(tagText)
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.8)
                            .textCase(.uppercase)
                            .foregroundStyle(Onyx.accent)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(Onyx.surface, in: Capsule())
                            .overlay { Capsule().strokeBorder(Onyx.hairline2, lineWidth: 0.75) }
                        Text(profile.prefix)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Onyx.textDim)
                    }
                    Text(profile.name)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Onyx.text)
                    Text("\(profile.executable.isEmpty ? "—" : profile.executable) · prefix: \(profile.prefix) · winver: \(profile.winver)")
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(Onyx.textDim)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    LaunchStopButton(
                        isLive: model.liveProfileIDs.contains(profile.id),
                        launchTitle: profile.isSteamApp ? "Launch Steam" : "Launch",
                        onLaunch: { model.launch(profile) },
                        onStop: {
                            if profile.isSteamApp { model.stopSteam() }
                            else { model.closeGame(profile) }
                        }
                    )
                }
            }
            .padding(EdgeInsets(top: 24, leading: 24, bottom: 18, trailing: 24))
        }
        .frame(height: 220)
        .clipped()
    }

    private var tagText: String {
        if profile.isSteamApp { return "Steam" }
        if profile.supportsModEngine { return "Modded" }
        if profile.requiresSteam { return "Steam Game" }
        return "Game"
    }

    // ── Tab bar ───────────────────────────────────────────────────────────
    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(tabs, id: \.self) { item in
                let active = tab == item
                Button { tab = item } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.icon).font(.system(size: 11))
                        Text(item.rawValue).font(.system(size: 12.5, weight: .medium))
                    }
                    .foregroundStyle(active ? Onyx.text : Onyx.textMute)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(active ? Onyx.accent : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .overlay(alignment: .bottom) { Rectangle().fill(Onyx.hairline).frame(height: 1) }
    }

    // ── App tab ───────────────────────────────────────────────────────────
    private var iconPathBinding: Binding<String> {
        Binding(
            get: { profile.iconPath ?? "" },
            set: { profile.iconPath = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        )
    }

    @ViewBuilder private var appTab: some View {
        if !profile.isSteamApp {
            CollapsibleCard(
                title: "How launching works",
                icon: "questionmark.circle.fill",
                storageKey: "profile.section.launch-help.collapsed",
                help: "The two ways games run in RipperMoonKit — through Steam, or straight from a game folder."
            ) {
                launchHelpContent
            }
        }

        Card(title: "App Settings", icon: "gamecontroller.fill") {
            VStack(alignment: .leading, spacing: 12) {
                FieldRow(label: "Name") { OnyxField(text: $profile.name) }
                FieldRow(label: "Icon") {
                    CoverArt(iconPath: profile.iconPath, label: profile.name,
                             seed: coverSeed(profile.name), corner: 7)
                        .frame(width: 30, height: 30)
                    OnyxField(text: iconPathBinding, mono: true, trailing: AnyView(
                        HStack(spacing: 6) {
                            Button { showCoverSearch = true } label: {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .foregroundStyle(Onyx.accent)
                            }
                            .buttonStyle(.plain)
                            .help("Find cover art on TheGamesDB")
                            Button { model.chooseIcon(for: &profile) } label: {
                                Image(systemName: "photo").foregroundStyle(Onyx.textMute)
                            }
                            .buttonStyle(.plain)
                            .help("Choose an image file")
                            Button { profile.iconPath = nil } label: {
                                Image(systemName: "xmark.circle").foregroundStyle(Onyx.textMute)
                            }
                            .buttonStyle(.plain)
                            .help("Clear icon")
                        }
                    ))
                }
                FieldRow(label: "Prefix") {
                    OnyxField(text: $profile.prefix)
                    Spacer()
                }
                FieldRow(label: "Winver") {
                    Picker("", selection: $profile.winver) {
                        Text("win10").tag("win10")
                        Text("win11").tag("win11")
                        Text("win7").tag("win7")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 220)
                    Spacer()
                }
            }
        }

        CollapsibleCard(
            title: "Paths",
            icon: "folder.fill",
            storageKey: "profile.section.paths.collapsed",
            help: "Where the game, executable, runner, and icon live. These paths let RipperMoonKit launch the right files without hard-coding your machine."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if !profile.isSteamApp {
                    PathEditor(title: "Folder", path: $profile.gameFolder) {
                        model.chooseFolder(current: profile.gameFolder) { profile.gameFolder = $0 }
                    }
                    .help("The folder containing the game's Windows executable. This is the working directory Wine/GPTK enters before launch.")
                    FieldRow(label: "Executable") {
                        OnyxField(text: $profile.executable, mono: true)
                        IconButton(systemImage: "doc.badge.gearshape", help: "Choose executable") {
                            model.chooseExecutable(for: &profile)
                        }
                    }
                    .help("The .exe RipperMoonKit starts for this profile. For Elden Ring Seamless, this is usually ersc_launcher.exe.")
                }
                PathEditor(title: "Runner", path: $profile.runnerPath) {
                    model.chooseFolder(current: profile.runnerPath) { profile.runnerPath = $0 }
                }
                .help("Optional Wine/GPTK runner override. Leave this alone unless a game needs a specific runner build.")
            }
        }
    }

    private var launchHelpContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            pathHintRow(
                icon: "cart.fill",
                title: "A Steam game",
                text: "Open the Steam app from your Library, sign in, and install the game inside Steam. Then launch it from Steam — or set the Folder and Executable below to the installed game."
            )
            pathHintRow(
                icon: "internaldrive.fill",
                title: "A standalone game or repack",
                text: "No Steam needed. Set the Folder and Executable below to the game's .exe, pick the Windows version, then press Launch."
            )
            Button { model.openHelpDocs(page: "gui.html") } label: {
                HStack(spacing: 5) {
                    Image(systemName: "book.fill").font(.system(size: 10))
                    Text("Open the full guide")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Onyx.accent)
            }
            .buttonStyle(.plain)
        }
    }

    private func pathHintRow(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Onyx.accent)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Onyx.text)
                Text(text)
                    .font(.system(size: 11))
                    .foregroundStyle(Onyx.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // ── Launch tab ────────────────────────────────────────────────────────
    @ViewBuilder private var launchTab: some View {
        CollapsibleCard(
            title: "Launch Options",
            icon: "switch.2",
            storageKey: "profile.section.launch-options.collapsed",
            help: "Runtime switches passed to GPTK/Wine. These tune compatibility, logging, graphics behavior, and DLL loading for this game."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if profile.isSteamManaged {
                    HStack(spacing: 18) {
                        Toggle("HUD", isOn: $profile.hud)
                            .help("Shows the Metal/GPTK performance overlay while the game runs.")
                        Toggle("No esync", isOn: $profile.noEsync)
                            .help("Disables esync for games or launchers that hang with Wine's eventfd synchronization.")
                    }
                    .toggleStyle(.checkbox)
                } else {
                    FlowLayout(spacing: 18) {
                        Toggle("Steam required", isOn: $profile.requiresSteam)
                            .help("Starts or expects Steam before launch. Use this when the game checks Steam APIs or uses Steam networking.")
                        Toggle("No DXR", isOn: $profile.noDXR)
                            .help("Disables DXR/ray tracing. This avoids unsupported D3D12 paths and often improves stability on Apple GPUs.")
                        Toggle("AVX", isOn: optionalBinding(\.avx))
                            .help("Enables AVX-related launch handling for games that require AVX-capable CPU behavior.")
                        Toggle("MetalFX/DLSS", isOn: optionalBinding(\.metalFX))
                            .help("Enables MetalFX integration where the runner supports it. Useful for upscaling paths exposed by GPTK.")
                        Toggle("HUD", isOn: $profile.hud)
                            .help("Shows the Metal/GPTK performance overlay while the game runs.")
                        Toggle("No esync", isOn: $profile.noEsync)
                            .help("Disables esync for games or launchers that hang with Wine's eventfd synchronization.")
                        Toggle("Native winmm", isOn: $profile.nativeWinmm)
                            .help("Loads a native winmm.dll first. Elden Ring Seamless uses this path for mod DLL loading.")
                        Toggle("Native steam_api64", isOn: $profile.nativeSteamAPI)
                            .help("Loads native steam_api64.dll first so Steam-dependent mods can call the bundled Steam API.")
                    }
                    .toggleStyle(.checkbox)
                    Rectangle().fill(Onyx.hairline).frame(height: 1)
                    FieldRow(label: "DLL overrides") {
                        OnyxField(text: Binding(
                            get: { profile.extraDllOverrides ?? "" },
                            set: { profile.extraDllOverrides = $0.isEmpty ? nil : $0 }
                        ), mono: true)
                    }
                    .help("Extra WINEDLLOVERRIDES entries for this game. Use only when a game or mod needs a specific native/builtin DLL order.")
                    FieldRow(label: "Arguments") {
                        OnyxField(text: $profile.extraArguments, mono: true)
                    }
                    .help("Arguments appended after the executable. Useful for flags like driver checks, renderer options, or game-specific launch switches.")
                }
            }
        }

        Card(title: "Actions", icon: "play.circle.fill") {
          VStack(alignment: .leading, spacing: 12) {
            if profile.isEldenRingERSC {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Onyx.accent)
                    Text("For co-op, open the Steam profile and use Install Spacewar once. Let Steam finish AppID 480 setup, then close Spacewar before launching Elden Ring.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Onyx.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Onyx.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Onyx.hairline, lineWidth: 0.75)
                }
            }

            FlowLayout(spacing: 8) {
                if profile.requiresSteam && !profile.isSteamManaged {
                    RMKButton(kind: .primary, icon: "play.fill", title: "Start Steam") {
                        model.startSteam(for: profile)
                    }
                }
                if profile.isSteamApp {
                    RMKButton(kind: model.steamReady ? .ghost : .primary,
                              icon: model.steamReady ? "wrench.and.screwdriver.fill" : "arrow.down.circle.fill",
                              title: model.steamReady ? "Repair Steam" : "Install Steam") {
                        model.installSteam()
                    }
                    .help("Downloads SteamSetup.exe if needed, starts Steam installation in the background, then validates that steam.exe exists.")
                }
                RMKButton(kind: .primary, icon: "gamecontroller.fill",
                          title: profile.isSteamApp ? "Launch Steam" : (profile.useModEngine == true ? "Launch Modded" : "Launch"),
                          disabled: profile.isSteamApp && !model.steamReady) {
                    model.launch(profile)
                }
                if profile.isSteamApp {
                    RMKButton(kind: .ghost, icon: "network", title: "Install Spacewar") {
                        model.installSpacewarFromSteam(for: profile)
                    }
                    .help("Launches Steam AppID 480 once so Steam can install Spacewar. Some co-op Steamworks test paths depend on this local Steam state.")
                }
                if !profile.isSteamApp {
                    RMKButton(kind: .ghost, icon: "xmark.circle.fill", title: "Close Game",
                              disabled: model.closeTargets(for: profile).isEmpty) {
                        model.closeGame(profile)
                    }
                }
                if profile.isSteamApp || profile.requiresSteam {
                    RMKButton(kind: .ghost, icon: "power", title: "Close Steam") {
                        model.stopSteam()
                    }
                }
                RMKButton(kind: .ghost, icon: "shippingbox.fill", title: "Install VC++ Runtime") {
                    model.installVCRuntime(for: profile)
                }
                if profile.supportsModEngine {
                    RMKButton(kind: .ghost, icon: "curlybraces", title: "Install .NET 6") {
                        model.installDotNet6(for: profile)
                    }
                }
                RMKButton(kind: .ghost, icon: "puzzlepiece.fill", title: "Install API Stubs") {
                    model.installStubs(for: profile)
                }
                RMKButton(kind: .ghost, icon: "doc.text.magnifyingglass", title: "Logs") {
                    model.openLogsFolder()
                }
                RMKButton(kind: .danger, icon: "trash", title: "Delete",
                          disabled: profile.isRequiredLibraryProfile) {
                    confirmDelete = true
                }
            }
          }
        }

        CollapsibleCard(
            title: "Validation",
            icon: "checkmark.seal.fill",
            storageKey: "profile.section.validation.collapsed",
            defaultCollapsed: true,
            help: "Quick checks for files this profile expects. Missing items here usually mean the path settings need correction."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if profile.isSteamApp {
                    ValidationRow(title: "Steam prefix",
                                  isOK: FileManager.default.fileExists(atPath: model.prefixPath(for: profile)))
                    ValidationRow(title: "steam.exe", isOK: model.steamExecutableExists(in: profile))
                } else if profile.isSteamLibraryGame {
                    ValidationRow(title: "Steam AppID \(profile.steamAppID ?? "")", isOK: true)
                    ValidationRow(title: "Install folder",
                                  isOK: FileManager.default.fileExists(atPath: profile.gameFolder))
                } else if profile.useModEngine == true {
                    ForEach(model.modEngineValidationItems(for: profile), id: \.title) { item in
                        ValidationRow(title: item.title, isOK: item.isOK)
                    }
                } else {
                    ValidationRow(title: profile.executable,
                                  isOK: model.fileExists(profile.executable, in: profile))
                    ForEach(profile.requiredFiles, id: \.self) { item in
                        ValidationRow(title: item, isOK: model.fileExists(item, in: profile))
                    }
                }
                ValidationRow(title: "Runner folder",
                              isOK: profile.runnerPath.isEmpty
                                  || FileManager.default.fileExists(atPath: profile.runnerPath))
            }
        }
    }

    private func optionalBinding(_ keyPath: WritableKeyPath<GameProfile, Bool?>) -> Binding<Bool> {
        Binding(
            get: { profile[keyPath: keyPath] ?? false },
            set: { profile[keyPath: keyPath] = $0 }
        )
    }

    // ── Commands tab ──────────────────────────────────────────────────────
    @ViewBuilder private var commandsTab: some View {
        CollapsibleCard(
            title: "Resolved Commands",
            icon: "chevron.left.forwardslash.chevron.right",
            storageKey: "profile.section.resolved-commands.collapsed",
            defaultCollapsed: true,
            help: "The exact shell commands RipperMoonKit will run after applying this profile's paths, prefix, DLL overrides, and launch flags."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if profile.requiresSteam && !profile.isSteamManaged {
                    CommandPreview(title: "Start Steam",
                                   command: model.previewStartSteamCommand(for: profile))
                    .help("Starts Steam in the configured prefix before launching a game that depends on Steam services.")
                }
                if profile.isSteamManaged {
                    if profile.isSteamApp {
                        CommandPreview(title: model.steamReady ? "Repair Steam" : "Install Steam",
                                       command: model.previewInstallSteamCommand())
                        .help("Starts Steam installation in the background and validates steam.exe when it appears.")
                    }
                    CommandPreview(title: profile.isSteamApp ? "Launch Steam" : "Launch From Steam",
                                   command: model.previewSteamManagedLaunchCommand(for: profile))
                    .help("Launches Steam directly, or asks Steam to launch the selected AppID.")
                    if profile.isSteamApp {
                        CommandPreview(title: "Install Spacewar",
                                       command: model.previewInstallSpacewarCommand(for: profile))
                        .help("Launches AppID 480 from Steam so Steam can install Spacewar for Steamworks co-op test paths.")
                    }
                } else if profile.useModEngine == true {
                    CommandPreview(title: "Launch Modded",
                                   command: model.previewModEngineLaunchCommand(for: profile))
                    .help("Runs ModEngine2 through GPTK/Wine and points it at the selected game executable.")
                    CommandPreview(title: "Run Randomizer",
                                   command: model.previewRandomizerCommand(for: profile))
                    .help("Starts the Elden Ring Randomizer GUI in the tools prefix so you can import options and generate mod files.")
                } else {
                    CommandPreview(title: "Launch",
                                   command: model.previewLaunchCommand(for: profile))
                    .help("Runs the configured executable directly through GPTK/Wine.")
                }
                if !profile.isSteamApp && !model.closeTargets(for: profile).isEmpty {
                    CommandPreview(title: "Close Game",
                                   command: model.previewCloseGameCommand(for: profile))
                    .help("Terminates this game's Windows processes without closing Steam.")
                }
                if profile.isSteamApp || profile.requiresSteam {
                    CommandPreview(title: "Close Steam",
                                   command: model.previewStopSteamCommand())
                    .help("Stops Steam and its helper processes when you are done using Steam-dependent games.")
                }
            }
        }
        ActivityCard()
    }
}
