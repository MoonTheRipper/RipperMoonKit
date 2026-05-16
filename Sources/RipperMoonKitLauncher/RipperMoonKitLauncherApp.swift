import AppKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct RipperMoonKitLauncherApp: App {
    @StateObject private var model = LauncherModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 1040, minHeight: 680)
        }
        .windowStyle(.titleBar)
    }
}

private enum SidebarSelection: Hashable {
    case library
    case profile(UUID)
    case backups
    case settings
}

private struct ContentView: View {
    @EnvironmentObject private var model: LauncherModel
    @State private var selection: SidebarSelection?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Library") {
                    Label("Games & Apps", systemImage: "square.grid.2x2.fill")
                        .tag(SidebarSelection.library)
                }

                Section("Toolkit") {
                    Label("Backups", systemImage: "clock.arrow.circlepath")
                        .tag(SidebarSelection.backups)
                    Label("Settings", systemImage: "gearshape.fill")
                        .tag(SidebarSelection.settings)
                }
            }
            .navigationTitle("RipperMoonKit")
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HeaderView(profile: headerProfile)

                    switch selection ?? model.defaultSelection {
                    case .library:
                        LibraryView(selection: $selection)
                    case .profile(let id):
                        if let profile = model.profileBinding(id: id) {
                            ProfileDetailView(profile: profile)
                        } else {
                            EmptyStateView(title: "Profile Missing", detail: "Choose another app or add a new one.")
                        }
                    case .backups:
                        BackupsView()
                    case .settings:
                        SettingsView()
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .onAppear {
            model.reload()
            selection = selection ?? model.defaultSelection
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    let profile = model.addProfile()
                    selection = .profile(profile.id)
                } label: {
                    Label("Add Game", systemImage: "plus")
                }
                .help("Add game or app")
            }
        }
        .sheet(isPresented: $model.showSetupGuide) {
            SetupGuideView()
                .environmentObject(model)
                .frame(width: 620)
        }
    }

    private var headerProfile: GameProfile? {
        guard case .profile(let id) = selection ?? model.defaultSelection else { return nil }
        return model.profiles.first { $0.id == id }
    }
}

private struct LibraryView: View {
    @EnvironmentObject private var model: LauncherModel
    @Binding var selection: SidebarSelection?

    private let columns = [
        GridItem(.adaptive(minimum: 170, maximum: 230), spacing: 14)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Library")
                        .font(.title.weight(.semibold))
                    Text("\(model.profiles.count) games and apps")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    let profile = model.addProfile()
                    selection = .profile(profile.id)
                } label: {
                    Label("Add Game", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                ForEach(model.profiles) { profile in
                    Button {
                        selection = .profile(profile.id)
                    } label: {
                        LibraryTile(profile: profile)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    let profile = model.addProfile()
                    selection = .profile(profile.id)
                } label: {
                    AddGameTile()
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct LibraryTile: View {
    let profile: GameProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileIconView(profile: profile, size: 64, appFallback: false)

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.headline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 154, alignment: .topLeading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.primary.opacity(0.08))
        }
    }

    private var subtitle: String {
        if profile.isSteamApp {
            return "Steam client"
        }
        if let steamAppID = profile.steamAppID, !steamAppID.isEmpty {
            return "Steam game · AppID \(steamAppID)"
        }
        if profile.requiresSteam {
            return "Uses Steam · \(profile.prefix)"
        }
        return "\(profile.prefix) · \(profile.executable)"
    }
}

private struct AddGameTile: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .semibold))
                .frame(width: 64, height: 64)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text("Add Game")
                .font(.headline)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 154)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                .foregroundStyle(.secondary.opacity(0.3))
        }
    }
}

private struct HeaderView: View {
    @EnvironmentObject private var model: LauncherModel
    let profile: GameProfile?

    var body: some View {
        HStack(spacing: 16) {
            ProfileIconView(profile: profile, size: 72, appFallback: true)

            VStack(alignment: .leading, spacing: 6) {
                Text(profile?.name ?? "RipperMoonKit")
                    .font(.largeTitle.weight(.semibold))
                Text(model.statusLine)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                model.reload()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct ProfileSidebarRow: View {
    let profile: GameProfile

    var body: some View {
        HStack(spacing: 8) {
            ProfileIconView(profile: profile, size: 24, appFallback: false)
            Text(profile.name)
                .lineLimit(1)
        }
    }
}

private struct ProfileIconView: View {
    let profile: GameProfile?
    let size: CGFloat
    let appFallback: Bool

    var body: some View {
        Group {
            if let image = profileImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else if appFallback {
                Image("RipperMoonKitLogo", bundle: .module)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: profile?.systemImage ?? "app.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.22)
                    .foregroundStyle(.secondary)
                    .background(.quaternary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: max(4, size * 0.12), style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: max(4, size * 0.12), style: .continuous)
                .strokeBorder(.primary.opacity(0.08))
        }
        .accessibilityHidden(true)
    }

    private var profileImage: NSImage? {
        guard let path = profile?.iconPath?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else {
            return nil
        }
        return NSImage(contentsOfFile: path)
    }
}

private struct ProfileDetailView: View {
    @EnvironmentObject private var model: LauncherModel
    @Binding var profile: GameProfile
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Panel("App Settings", systemImage: profile.systemImage) {
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                    GridRow {
                        FieldLabel("Name")
                        TextField("Name", text: $profile.name)
                            .textFieldStyle(.roundedBorder)
                    }

                    GridRow {
                        FieldLabel("Icon")
                        HStack(spacing: 10) {
                            ProfileIconView(profile: profile, size: 36, appFallback: false)
                            TextField("Icon image path", text: iconPathBinding)
                                .textFieldStyle(.roundedBorder)
                            Button {
                                model.chooseIcon(for: &profile)
                            } label: {
                                Image(systemName: "photo")
                            }
                            .buttonStyle(.bordered)
                            .help("Choose icon image")
                            Button {
                                profile.iconPath = nil
                            } label: {
                                Image(systemName: "xmark.circle")
                            }
                            .buttonStyle(.bordered)
                            .help("Clear icon")
                            .disabled((profile.iconPath ?? "").isEmpty)
                        }
                    }

                    GridRow {
                        FieldLabel("Prefix")
                        TextField("Prefix", text: $profile.prefix)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 260)
                    }

                    GridRow {
                        FieldLabel("Winver")
                        Picker("Winver", selection: $profile.winver) {
                            Text("win10").tag("win10")
                            Text("win11").tag("win11")
                            Text("win7").tag("win7")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }
                }
            }

            Panel("Paths", systemImage: "folder.fill") {
                if !profile.isSteamApp {
                    PathEditor(title: "Folder", path: $profile.gameFolder) {
                        model.chooseFolder(current: profile.gameFolder) { profile.gameFolder = $0 }
                    }

                    HStack(spacing: 10) {
                        FieldLabel("Executable")
                        TextField("Executable", text: $profile.executable)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            model.chooseExecutable(for: &profile)
                        } label: {
                            Image(systemName: "doc.badge.gearshape")
                        }
                        .buttonStyle(.bordered)
                        .help("Choose executable")
                    }
                }

                PathEditor(title: "Runner", path: $profile.runnerPath) {
                    model.chooseFolder(current: profile.runnerPath) { profile.runnerPath = $0 }
                }
            }

            Panel("Launch Options", systemImage: "switch.2") {
                if profile.isSteamManaged {
                    HStack(spacing: 18) {
                        Toggle("HUD", isOn: $profile.hud)
                        Toggle("No esync", isOn: $profile.noEsync)
                    }
                    .toggleStyle(.checkbox)
                } else {
                    HStack(spacing: 18) {
                        Toggle("Steam required", isOn: $profile.requiresSteam)
                        Toggle("No DXR", isOn: $profile.noDXR)
                        Toggle("MetalFX/DLSS", isOn: Binding(
                            get: { profile.metalFX ?? false },
                            set: { profile.metalFX = $0 }
                        ))
                        Toggle("HUD", isOn: $profile.hud)
                        Toggle("No esync", isOn: $profile.noEsync)
                    }
                    .toggleStyle(.checkbox)

                    HStack(spacing: 18) {
                        Toggle("Native winmm", isOn: $profile.nativeWinmm)
                        Toggle("Native steam_api64", isOn: $profile.nativeSteamAPI)
                    }
                    .toggleStyle(.checkbox)

                    HStack(spacing: 10) {
                        FieldLabel("Arguments")
                        TextField("Extra arguments", text: $profile.extraArguments)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            Panel("Actions", systemImage: "play.circle.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        if profile.requiresSteam && !profile.isSteamManaged {
                            Button {
                                model.startSteam(for: profile)
                            } label: {
                                Label("Start Steam", systemImage: "play.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        Button {
                            model.launch(profile)
                        } label: {
                            Label(profile.isSteamApp ? "Launch Steam" : "Launch", systemImage: profile.isSteamManaged ? "play.fill" : "gamecontroller.fill")
                        }
                        .buttonStyle(.borderedProminent)

                        if !profile.isSteamApp {
                            Button {
                                model.closeGame(profile)
                            } label: {
                                Label("Close Game", systemImage: "xmark.circle.fill")
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.closeTargets(for: profile).isEmpty)
                        }

                        if profile.isSteamApp {
                            Button(role: .destructive) {
                                model.stopSteam()
                            } label: {
                                Label("Stop Steam", systemImage: "power")
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            model.installVCRuntime(for: profile)
                        } label: {
                            Label("Install VC++ Runtime", systemImage: "shippingbox.fill")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            model.installStubs(for: profile)
                        } label: {
                            Label("Install API Stubs", systemImage: "puzzlepiece.fill")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            model.openLogsFolder()
                        } label: {
                            Label("Logs", systemImage: "doc.text.magnifyingglass")
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .disabled(profile.isRequiredLibraryProfile)
                    }
                }
            }

            Panel("Validation", systemImage: "checkmark.seal.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    if profile.isSteamApp {
                        ValidationRow(title: "Steam prefix", isOK: FileManager.default.fileExists(atPath: model.prefixPath(for: profile)))
                        ValidationRow(title: "steam.exe", isOK: model.steamExecutableExists(in: profile))
                    } else if profile.isSteamLibraryGame {
                        ValidationRow(title: "Steam AppID \(profile.steamAppID ?? "")", isOK: true)
                        ValidationRow(title: "Install folder", isOK: FileManager.default.fileExists(atPath: profile.gameFolder))
                    } else {
                        ValidationRow(title: profile.executable, isOK: model.fileExists(profile.executable, in: profile))
                        ForEach(profile.requiredFiles, id: \.self) { item in
                            ValidationRow(title: item, isOK: model.fileExists(item, in: profile))
                        }
                    }
                    ValidationRow(title: "Runner folder", isOK: profile.runnerPath.isEmpty || FileManager.default.fileExists(atPath: profile.runnerPath))
                }
            }

            Panel("Commands", systemImage: "chevron.left.forwardslash.chevron.right") {
                VStack(alignment: .leading, spacing: 12) {
                    if profile.requiresSteam && !profile.isSteamManaged {
                        CommandPreview(title: "Start Steam", command: model.previewStartSteamCommand(for: profile))
                    }
                    if profile.isSteamManaged {
                        CommandPreview(title: profile.isSteamApp ? "Launch Steam" : "Launch From Steam", command: model.previewSteamManagedLaunchCommand(for: profile))
                    } else {
                        CommandPreview(title: "Launch", command: model.previewLaunchCommand(for: profile))
                    }
                    if !profile.isSteamApp && !model.closeTargets(for: profile).isEmpty {
                        CommandPreview(title: "Close Game", command: model.previewCloseGameCommand(for: profile))
                    }
                    if profile.isSteamApp {
                        CommandPreview(title: "Stop Steam", command: model.previewStopSteamCommand())
                    }
                }
            }

            CommandOutputView()
        }
        .onChange(of: profile) { _, _ in
            model.persistProfiles()
        }
        .confirmationDialog("Delete this app profile?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                model.deleteProfile(id: profile.id)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var iconPathBinding: Binding<String> {
        Binding(
            get: { profile.iconPath ?? "" },
            set: { profile.iconPath = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        )
    }
}

private struct BackupsView: View {
    @EnvironmentObject private var model: LauncherModel
    @State private var selectedBackup: BackupItem.ID?
    @State private var confirmRollback = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Panel("Update Safeguards", systemImage: "externaldrive.badge.timemachine") {
                HStack(spacing: 12) {
                    Button {
                        model.createBackupOnly()
                    } label: {
                        Label("Create Backup", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        model.refreshBackups()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        confirmRollback = true
                    } label: {
                        Label("Rollback", systemImage: "arrow.uturn.backward.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedBackup == nil)
                }
            }

            Panel("Backups", systemImage: "archivebox.fill") {
                List(model.backups, selection: $selectedBackup) { backup in
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(backup.name)
                                .font(.headline)
                            Text(backup.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .tag(backup.id)
                }
                .frame(minHeight: 220)
            }
        }
        .confirmationDialog("Rollback selected backup?", isPresented: $confirmRollback) {
            Button("Rollback", role: .destructive) {
                if let selectedBackup {
                    model.rollbackBackup(id: selectedBackup)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var model: LauncherModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Panel("Paths", systemImage: "folder.fill") {
                PathEditor(title: "GPTK Home", path: $model.pathSettings.gptkHome) {
                    model.chooseFolder(current: model.pathSettings.gptkHome) { model.pathSettings.gptkHome = $0 }
                }
                PathEditor(title: "Prefix Root", path: $model.pathSettings.prefixRoot) {
                    model.chooseFolder(current: model.pathSettings.prefixRoot) { model.pathSettings.prefixRoot = $0 }
                }
                PathEditor(title: "Games Root", path: $model.pathSettings.gamesRoot) {
                    model.chooseFolder(current: model.pathSettings.gamesRoot) { model.pathSettings.gamesRoot = $0 }
                }
                PathEditor(title: "External Root", path: $model.pathSettings.externalRoot) {
                    model.chooseFolder(current: model.pathSettings.externalRoot) { model.pathSettings.externalRoot = $0 }
                }
                PathEditor(title: "Steam Library", path: $model.pathSettings.steamLibrary) {
                    model.chooseFolder(current: model.pathSettings.steamLibrary) { model.pathSettings.steamLibrary = $0 }
                }
                PathEditor(title: "Toolkit Source", path: $model.toolkitSourceFolder) {
                    model.chooseFolder(current: model.toolkitSourceFolder) { model.toolkitSourceFolder = $0 }
                }

                HStack {
                    Spacer()
                    Button {
                        model.savePathSettings()
                    } label: {
                        Label("Save Paths", systemImage: "square.and.arrow.down.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Panel("Drive Mappings", systemImage: "externaldrive.connected.to.line.below.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach($model.driveMaps) { $drive in
                        HStack(spacing: 10) {
                            TextField("Letter", text: $drive.letter)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 64)
                            TextField("Path", text: $drive.path)
                                .textFieldStyle(.roundedBorder)
                            Button {
                                model.chooseFolder(current: drive.path) { drive.path = $0 }
                            } label: {
                                Image(systemName: "folder")
                            }
                            .buttonStyle(.bordered)
                            Button(role: .destructive) {
                                model.removeDriveMap(id: drive.id)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    HStack {
                        Button {
                            model.addDriveMap()
                        } label: {
                            Label("Add Drive", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button {
                            model.saveDriveMaps()
                        } label: {
                            Label("Save Drives", systemImage: "square.and.arrow.down.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            Panel("Maintenance", systemImage: "wrench.and.screwdriver.fill") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Button {
                            model.installToolkit()
                        } label: {
                            Label("Install Toolkit", systemImage: "square.and.arrow.down.fill")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            model.installDependencies()
                        } label: {
                            Label("Install GPTK", systemImage: "externaldrive.fill.badge.plus")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            model.updateFromGitHub()
                        } label: {
                            Label("Update From GitHub", systemImage: "arrow.down.circle.fill")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            model.installVCRuntimeGlobally()
                        } label: {
                            Label("Install VC++ Runtime", systemImage: "shippingbox.fill")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            model.installStubsGlobally()
                        } label: {
                            Label("Install API Stubs", systemImage: "puzzlepiece.fill")
                        }
                        .buttonStyle(.bordered)
                    }

                    Divider()

                    HStack(spacing: 18) {
                        Toggle("Remove config", isOn: $model.removeConfigOnUninstall)
                        Toggle("Remove Wine prefixes and saves", isOn: $model.removePrefixesOnUninstall)
                    }
                    .toggleStyle(.checkbox)

                    Button(role: .destructive) {
                        model.uninstallToolkit()
                    } label: {
                        Label("Uninstall Toolkit", systemImage: "trash.fill")
                    }
                    .buttonStyle(.bordered)
                }
            }

            CommandOutputView()
        }
    }
}

private struct SetupGuideView: View {
    @EnvironmentObject private var model: LauncherModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image("RipperMoonKitLogo", bundle: .module)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("First Run Setup")
                        .font(.title2.weight(.semibold))
                    Text("Initialize the toolkit paths and Apple Game Porting Toolkit before launching games.")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                SetupRow(title: "Toolkit scripts", isOK: model.config.hasToolkitScripts)
                SetupRow(title: "GPTK Wine runner", isOK: model.config.hasWineRunner)
                SetupRow(title: "D3DMetal runtime", isOK: model.config.hasD3DMetalRuntime)
                SetupRow(title: "Config file", isOK: model.config.exists)
            }

            HStack(spacing: 12) {
                Button {
                    model.installToolkit()
                } label: {
                    Label("Install Toolkit", systemImage: "square.and.arrow.down.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    model.installDependencies()
                } label: {
                    Label("Install GPTK", systemImage: "externaldrive.fill.badge.plus")
                }
                .buttonStyle(.bordered)

                Button {
                    model.openGPTKPage()
                } label: {
                    Label("Apple GPTK Page", systemImage: "safari.fill")
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Spacer()
                Button {
                    model.dismissSetupGuide()
                } label: {
                    Text("Done")
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
    }
}

private struct SetupRow: View {
    let title: String
    let isOK: Bool

    var body: some View {
        HStack {
            Image(systemName: isOK ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(isOK ? .green : .orange)
            Text(title)
            Spacer()
            Text(isOK ? "Ready" : "Needs setup")
                .foregroundStyle(.secondary)
        }
    }
}

private struct Panel<Content: View>: View {
    private let title: String
    private let systemImage: String
    @ViewBuilder private let content: Content

    init(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .symbolRenderingMode(.hierarchical)

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.primary.opacity(0.08))
        }
    }
}

private struct EmptyStateView: View {
    let title: String
    let detail: String

    var body: some View {
        Panel(title, systemImage: "questionmark.folder.fill") {
            Text(detail)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FieldLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.callout.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(width: 112, alignment: .leading)
    }
}

private struct PathEditor: View {
    let title: String
    @Binding var path: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            FieldLabel(title)
            TextField(title, text: $path)
                .textFieldStyle(.roundedBorder)
            Button {
                action()
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.bordered)
            .help("Choose \(title)")
        }
    }
}

private struct ValidationRow: View {
    let title: String
    let isOK: Bool

    var body: some View {
        HStack {
            Image(systemName: isOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isOK ? .green : .red)
            Text(title)
            Spacer()
            Text(isOK ? "Found" : "Missing")
                .foregroundStyle(.secondary)
        }
    }
}

private struct CommandPreview: View {
    let title: String
    let command: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout.weight(.medium))
            Text(command)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct CommandOutputView: View {
    @EnvironmentObject private var model: LauncherModel

    var body: some View {
        Panel("Activity", systemImage: "waveform.path.ecg") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                        .opacity(model.isRunning ? 1 : 0)
                    Text(model.lastResult)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                Text(model.commandOutput.isEmpty ? "No activity yet." : model.commandOutput)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                    .padding(10)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

@MainActor
private final class LauncherModel: ObservableObject {
    @Published var config = ToolkitConfig.load()
    @Published var profiles: [GameProfile]
    @Published var pathSettings: PathSettings
    @Published var driveMaps: [DriveMap]
    @Published var toolkitSourceFolder: String
    @Published var isRunning = false
    @Published var commandOutput = ""
    @Published var lastResult = "Ready"
    @Published var backups: [BackupItem] = []
    @Published var removeConfigOnUninstall = false
    @Published var removePrefixesOnUninstall = false
    @Published var showSetupGuide = false

    private let defaults = UserDefaults.standard
    private let setupGuideSeenKey = "setupGuideSeen.v2"

    var defaultSelection: SidebarSelection {
        .library
    }

    var statusLine: String {
        config.exists ? "Config loaded from \(config.configPath)" : "Config not found at \(config.configPath)"
    }

    init() {
        let loaded = ToolkitConfig.load()
        config = loaded
        profiles = Self.loadProfiles(config: loaded, defaults: defaults)
        pathSettings = PathSettings(config: loaded)
        driveMaps = DriveMap.parse(loaded.values["GPTK_DRIVE_MAPS"] ?? "")
        toolkitSourceFolder = defaults.string(forKey: "toolkitSourceFolder") ?? "\(loaded.home)/Desktop/RipperMoonToolKit"
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
        if !config.needsSetupGuide {
            defaults.set(true, forKey: setupGuideSeenKey)
            showSetupGuide = false
        } else {
            showSetupGuide = shouldShowSetupGuide(config: config)
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
        persistProfiles()
    }

    func persistProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: "gameProfiles.v1")
        }
    }

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

    func fileExists(_ relativePath: String, in profile: GameProfile) -> Bool {
        guard !relativePath.isEmpty else { return false }
        let path = URL(fileURLWithPath: profile.gameFolder).appendingPathComponent(relativePath).path
        return FileManager.default.fileExists(atPath: path)
    }

    func prefixPath(for profile: GameProfile) -> String {
        if profile.prefix.hasPrefix("/") || profile.prefix.hasPrefix("./") || profile.prefix.hasPrefix("../") {
            return NSString(string: profile.prefix).expandingTildeInPath
        }
        return "\(config.prefixRoot)/\(profile.prefix)"
    }

    func steamExecutableExists(in profile: GameProfile) -> Bool {
        FileManager.default.fileExists(atPath: "\(prefixPath(for: profile))/drive_c/Program Files (x86)/Steam/steam.exe")
    }

    func startSteam(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        runShell(
            title: "Start Steam",
            command: previewStartSteamCommand(for: profile, detached: true),
            detached: true
        )
    }

    func stopSteam() {
        runShell(title: "Stop Steam", command: previewStopSteamCommand())
    }

    func closeGame(_ profile: GameProfile) {
        let profile = repairedProfile(profile)
        runShell(title: "Close \(profile.name)", command: previewCloseGameCommand(for: profile))
    }

    func launch(_ profile: GameProfile) {
        let profile = repairedProfile(profile)
        runShell(
            title: "Launch \(profile.name)",
            command: profile.isSteamManaged ? previewSteamManagedLaunchCommand(for: profile, detached: true) : previewLaunchCommand(for: profile, detached: true),
            detached: true
        )
    }

    func installVCRuntime(for profile: GameProfile) {
        let profile = repairedProfile(profile)
        runShell(
            title: "Install VC++ Runtime",
            command: "\(sourceConfig); \(config.gptkVCRunPath.shellQuoted) --prefix \(profile.prefix.shellQuoted)"
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

    func createBackupOnly() {
        runShell(
            title: "Create Backup",
            command: "cd \(toolkitSourceFolder.shellQuoted) && ./install.zsh --skip-deps --backup-only",
            completion: { [weak self] in self?.refreshBackups() }
        )
    }

    func installToolkit() {
        runShell(
            title: "Install Toolkit",
            command: "cd \(toolkitSourceFolder.shellQuoted) && ./install.zsh --skip-deps",
            completion: { [weak self] in self?.refreshBackups() }
        )
    }

    func installDependencies() {
        runShell(
            title: "Install GPTK",
            command: "cd \(toolkitSourceFolder.shellQuoted) && RIPPERMOON_OPEN_GPTK_PAGE=1 ./install.zsh",
            completion: { [weak self] in self?.reload() }
        )
    }

    func updateFromGitHub() {
        let command = """
        cd \(toolkitSourceFolder.shellQuoted) && \
        git fetch --tags origin && \
        if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then git pull --ff-only origin main; else echo "Already up to date."; fi && \
        ./install.zsh --skip-deps && \
        zsh scripts/install-gui-app.zsh
        """
        runShell(
            title: "Update From GitHub",
            command: command,
            completion: { [weak self] in self?.reload() }
        )
    }

    func uninstallToolkit() {
        var args: [String] = []
        if removeConfigOnUninstall {
            args.append("--remove-config")
        }
        if removePrefixesOnUninstall {
            args.append("--remove-prefixes")
        }

        runShell(
            title: "Uninstall Toolkit",
            command: "cd \(toolkitSourceFolder.shellQuoted) && zsh scripts/uninstall.zsh \(args.joined(separator: " "))",
            completion: { [weak self] in self?.reload() }
        )
    }

    func rollbackBackup(id: BackupItem.ID) {
        guard let backup = backups.first(where: { $0.id == id }) else { return }
        runShell(
            title: "Rollback",
            command: "cd \(toolkitSourceFolder.shellQuoted) && ./install.zsh --rollback \(backup.name.shellQuoted)",
            completion: { [weak self] in self?.refreshBackups() }
        )
    }

    func refreshBackups() {
        let backupRoot = URL(fileURLWithPath: config.gptkHome).appendingPathComponent("backups")
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: backupRoot,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        backups = contents
            .filter { $0.lastPathComponent.hasPrefix("rippermoon-update-") }
            .map { url in
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return BackupItem(name: url.lastPathComponent, path: url.path, modified: modified)
            }
            .sorted { $0.modified > $1.modified }
    }

    func openLogsFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: config.logsPath))
    }

    func openGPTKPage() {
        NSWorkspace.shared.open(URL(string: config.gptkDownloadPage)!)
    }

    func dismissSetupGuide() {
        defaults.set(true, forKey: setupGuideSeenKey)
        showSetupGuide = false
    }

    private func shouldShowSetupGuide(config: ToolkitConfig) -> Bool {
        !defaults.bool(forKey: setupGuideSeenKey) && config.needsSetupGuide
    }

    func addDriveMap() {
        let used = Set(driveMaps.map { $0.letter.uppercased() })
        let letter = (["D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "T", "U", "V", "W", "Y", "Z"].first { !used.contains($0) }) ?? "D"
        driveMaps.append(DriveMap(letter: letter, path: config.externalRoot))
    }

    func removeDriveMap(id: UUID) {
        driveMaps.removeAll { $0.id == id }
    }

    func savePathSettings() {
        defaults.set(toolkitSourceFolder, forKey: "toolkitSourceFolder")
        saveEnvValues([
            "GPTK_HOME": envPath(pathSettings.gptkHome),
            "GPTK_PREFIX_ROOT": envPath(pathSettings.prefixRoot),
            "GPTK_GAMES_ROOT": envPath(pathSettings.gamesRoot),
            "GPTK_EXTERNAL_ROOT": envPath(pathSettings.externalRoot),
            "GPTK_STEAM_LIBRARY": envPath(pathSettings.steamLibrary)
        ])
    }

    func saveDriveMaps() {
        var seen = Set<String>()
        var parts: [String] = []

        for map in driveMaps {
            let letter = map.letter.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let path = map.path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard letter.count == 1, letter != "C", !path.isEmpty, !seen.contains(letter) else {
                continue
            }
            seen.insert(letter)
            parts.append("\(letter)=\(envPath(path))")
        }

        driveMaps = parts.compactMap { DriveMap(line: $0) }
        saveEnvValues(["GPTK_DRIVE_MAPS": parts.joined(separator: ";")])
    }

    func previewStartSteamCommand(for profile: GameProfile, detached: Bool = false) -> String {
        let logPath = "\(config.logsPath)/\(profile.safeName)-steam.log"
        let envPart = steamEnvAssignment(for: profile)
        let base = "\(sourceConfig); nohup env \(envPart) \(config.gptkSteamPath.shellQuoted) --no-log >> \(logPath.shellQuoted) 2>&1 &"
        return detached ? base : "\(sourceConfig); env \(envPart) \(config.gptkSteamPath.shellQuoted) --no-log"
    }

    func previewStopSteamCommand() -> String {
        "\(sourceConfig); \(config.gptkSteamPath.shellQuoted) --kill"
    }

    func previewSteamManagedLaunchCommand(for profile: GameProfile, detached: Bool = false) -> String {
        let logPath = "\(config.logsPath)/\(profile.safeName).log"
        let appLaunch = (profile.steamAppID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let appArgs = appLaunch.isEmpty ? "" : " -applaunch \(appLaunch.shellQuoted)"
        let envPart = steamEnvAssignment(for: profile)
        let launch = "nohup env \(envPart) \(config.gptkSteamPath.shellQuoted) --no-log\(appArgs) >> \(logPath.shellQuoted) 2>&1 &"

        if detached {
            return "\(sourceConfig); \(launch)"
        }
        return "\(sourceConfig); env \(envPart) \(config.gptkSteamPath.shellQuoted) --no-log\(appArgs)"
    }

    func previewCloseGameCommand(for profile: GameProfile) -> String {
        let commands = closeTargets(for: profile).map { target in
            "env \(runnerEnvAssignment(for: profile)) \(config.gptkLaunchPath.shellQuoted) --prefix \(profile.prefix.shellQuoted) --no-log -- taskkill /IM \(target.shellQuoted) /F >/dev/null 2>&1 || true"
        }
        if commands.isEmpty {
            return "\(sourceConfig); echo \("No process target configured for \(profile.name)".shellQuoted)"
        }
        return "\(sourceConfig); \(commands.joined(separator: "; "))"
    }

    func previewLaunchCommand(for profile: GameProfile, detached: Bool = false) -> String {
        let logPath = "\(config.logsPath)/\(profile.safeName).log"
        var args: [String] = ["--prefix", profile.prefix, "--set-winver", profile.winver]
        if profile.noDXR { args.append("--no-dxr") }
        if profile.noEsync { args.append("--no-esync") }
        if profile.metalFX == true { args.append("--metalfx") }
        if profile.hud { args.append("--hud") }
        args.append(contentsOf: ["--log-file", logPath, "--", "./\(profile.executable)"])

        let extra = profile.extraArguments.trimmingCharacters(in: .whitespacesAndNewlines)
        let extraPart = extra.isEmpty ? "" : " \(extra)"
        let overrides = dllOverrides(for: profile)
        let launch = "cd \(profile.gameFolder.shellQuoted) && nohup env \(runnerEnvAssignment(for: profile)) WINEDLLOVERRIDES=\(overrides.shellQuoted) \(config.gptkLaunchPath.shellQuoted) \(args.map(\.shellQuoted).joined(separator: " "))\(extraPart) >> \(logPath.shellQuoted) 2>&1 &"

        if detached {
            return "\(sourceConfig); \(launch)"
        }
        return "\(sourceConfig); cd \(profile.gameFolder.shellQuoted) && env \(runnerEnvAssignment(for: profile)) WINEDLLOVERRIDES=\(overrides.shellQuoted) \(config.gptkLaunchPath.shellQuoted) \(args.map(\.shellQuoted).joined(separator: " "))\(extraPart)"
    }

    func closeTargets(for profile: GameProfile) -> [String] {
        var targets: [String] = []
        let executable = (profile.executable as NSString).lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !executable.isEmpty {
            targets.append(executable)
        }
        if profile.isEldenRingERSC {
            targets.append("eldenring.exe")
        }
        var seen = Set<String>()
        return targets.filter { seen.insert($0.localizedLowercase).inserted }
    }

    private var sourceConfig: String {
        "[[ -r \(config.configPath.shellQuoted) ]] && source \(config.configPath.shellQuoted)"
    }

    private func runnerEnvAssignment(for profile: GameProfile) -> String {
        profile.runnerPath.isEmpty ? "" : "GPTK_WINE_HOME=\(profile.runnerPath.shellQuoted)"
    }

    private func steamEnvAssignment(for profile: GameProfile) -> String {
        var assignments: [String] = []
        if !profile.runnerPath.isEmpty {
            assignments.append("GPTK_WINE_HOME=\(profile.runnerPath.shellQuoted)")
        }
        assignments.append("GPTK_MTL_HUD_ENABLED=\(profile.hud ? "1" : "0")")
        assignments.append("GPTK_WINEESYNC=\(profile.noEsync ? "0" : "1")")
        return assignments.joined(separator: " ")
    }

    private func dllOverrides(for profile: GameProfile) -> String {
        var values: [String] = []
        if profile.nativeWinmm { values.append("winmm=n,b") }
        if profile.nativeSteamAPI { values.append("steam_api64=n,b") }
        if profile.metalFX == true {
            values.append("nvapi64=b,n")
            values.append("nvngx=b,n")
        }
        return values.joined(separator: ";")
    }

    private func envPath(_ path: String) -> String {
        if path == config.home {
            return "$HOME"
        }
        if path.hasPrefix(config.home + "/") {
            return "$HOME/" + path.dropFirst(config.home.count + 1)
        }
        return path
    }

    private func saveEnvValues(_ values: [String: String]) {
        do {
            try backupConfigForEdit()
            var lines: [String]
            if FileManager.default.fileExists(atPath: config.configPath) {
                let text = try String(contentsOfFile: config.configPath, encoding: .utf8)
                lines = text.components(separatedBy: .newlines)
            } else {
                lines = ["# RipperMoonToolKit configuration"]
            }

            var remaining = Set(values.keys)
            for index in lines.indices {
                let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
                let body = trimmed.hasPrefix("export ") ? String(trimmed.dropFirst("export ".count)) : trimmed
                guard let equal = body.firstIndex(of: "=") else { continue }
                let key = String(body[..<equal]).trimmingCharacters(in: .whitespaces)
                if let value = values[key] {
                    lines[index] = "export \(key)=\"\(value.envEscaped)\""
                    remaining.remove(key)
                }
            }

            for key in remaining.sorted() {
                lines.append("export \(key)=\"\(values[key, default: ""].envEscaped)\"")
            }

            try lines.joined(separator: "\n").write(toFile: config.configPath, atomically: true, encoding: .utf8)
            config = ToolkitConfig.load()
            pathSettings = PathSettings(config: config)
            lastResult = "Saved config"
        } catch {
            lastResult = "Config save failed"
            commandOutput += "\(error.localizedDescription)\n"
        }
    }

    private func backupConfigForEdit() throws {
        guard FileManager.default.fileExists(atPath: config.configPath) else { return }
        let stamp = DateFormatter.backupStamp.string(from: Date())
        let backup = "\(config.gptkHome)/backups/env-edit-\(stamp)/.rippermoon-gptk.env"
        try FileManager.default.createDirectory(atPath: (backup as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: config.configPath, toPath: backup)
    }

    private func runShell(title: String, command: String, detached: Bool = false, completion: (() -> Void)? = nil) {
        defaults.set(toolkitSourceFolder, forKey: "toolkitSourceFolder")
        isRunning = true
        lastResult = "\(title) running"
        commandOutput = "$ \(command)\n"

        Task {
            let result = await ShellExecutor.run(command)
            isRunning = false
            commandOutput += result.output
            if let error = result.error {
                commandOutput += "\(error)\n"
                lastResult = "\(title) failed"
            } else {
                lastResult = detached ? "\(title) sent" : "\(title) finished with status \(result.status)"
            }
            completion?()
        }
    }

    private static func loadProfiles(config: ToolkitConfig, defaults: UserDefaults) -> [GameProfile] {
        if let data = defaults.data(forKey: "gameProfiles.v1"),
           let profiles = try? JSONDecoder().decode([GameProfile].self, from: data),
           !profiles.isEmpty {
            return repairProfiles(profiles, config: config)
        }
        return repairProfiles([GameProfile.steam(config: config), GameProfile.eldenRing(config: config, defaults: defaults)], config: config)
    }

    private static func repairProfiles(_ profiles: [GameProfile], config: ToolkitConfig) -> [GameProfile] {
        var repaired = profiles.map { $0.repairedForCurrentToolkit(config: config) }

        if !repaired.contains(where: { $0.isSteamApp }) {
            repaired.insert(GameProfile.steam(config: config), at: 0)
        }

        if let steamIndex = repaired.firstIndex(where: { $0.isSteamApp }), steamIndex != 0 {
            let steam = repaired.remove(at: steamIndex)
            repaired.insert(steam, at: 0)
        }

        for steamGame in discoverSteamGames(config: config) {
            if let existingIndex = repaired.firstIndex(where: { $0.steamAppID == steamGame.steamAppID }) {
                repaired[existingIndex].name = repaired[existingIndex].name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? steamGame.name : repaired[existingIndex].name
                repaired[existingIndex].gameFolder = steamGame.gameFolder
                repaired[existingIndex].prefix = repaired[existingIndex].prefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Steam" : repaired[existingIndex].prefix
                repaired[existingIndex].requiresSteam = true
                repaired[existingIndex].systemImage = repaired[existingIndex].systemImage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? steamGame.systemImage : repaired[existingIndex].systemImage
            } else {
                repaired.append(steamGame)
            }
        }

        return repaired
    }

    private func repairedProfile(_ profile: GameProfile) -> GameProfile {
        let repaired = profile.repairedForCurrentToolkit(config: config)
        guard repaired != profile else { return profile }

        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = repaired
            persistProfiles()
        }
        return repaired
    }

    private static func discoverSteamGames(config: ToolkitConfig) -> [GameProfile] {
        let steamAppsURL = URL(fileURLWithPath: config.steamLibrary).appendingPathComponent("steamapps")
        let manifestURLs = ((try? FileManager.default.contentsOfDirectory(
            at: steamAppsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? [])
            .filter { url in
                let name = url.lastPathComponent
                return name.hasPrefix("appmanifest_") && name.hasSuffix(".acf")
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        return manifestURLs.compactMap { url in
            guard let text = try? String(contentsOf: url, encoding: .utf8),
                  let appID = acfValue("appid", in: text),
                  let name = acfValue("name", in: text),
                  let installDir = acfValue("installdir", in: text),
                  !appID.isEmpty,
                  !name.isEmpty,
                  !installDir.isEmpty else {
                return nil
            }

            return GameProfile.steamGame(appID: appID, name: name, installDir: installDir, config: config)
        }
    }

    private static func acfValue(_ key: String, in text: String) -> String? {
        let pattern = #""\#(key)"\s+"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[valueRange])
    }
}

private enum ShellExecutor {
    static func run(_ command: String) async -> ShellResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-lc", command]
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: ShellResult(status: process.terminationStatus, output: output, error: nil))
                } catch {
                    continuation.resume(returning: ShellResult(status: -1, output: "", error: error.localizedDescription))
                }
            }
        }
    }
}

private struct ShellResult: Sendable {
    let status: Int32
    let output: String
    let error: String?
}

private struct GameProfile: Codable, Identifiable, Hashable {
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
    var metalFX: Bool?
    var hud: Bool
    var noEsync: Bool
    var nativeWinmm: Bool
    var nativeSteamAPI: Bool
    var extraArguments: String
    var requiredFiles: [String]
    var systemImage: String

    var safeName: String {
        name.replacingOccurrences(of: "[^A-Za-z0-9._-]+", with: "-", options: .regularExpression)
    }

    var isEldenRingERSC: Bool {
        id == Self.eldenRingERSCID ||
            executable.localizedCaseInsensitiveContains("ersc_launcher.exe") ||
            name.localizedCaseInsensitiveContains("elden ring ersc")
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
        repaired.noEsync = false
        repaired.nativeWinmm = true
        repaired.nativeSteamAPI = true
        repaired.systemImage = "gamecontroller.fill"

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
            metalFX: false,
            hud: defaults.object(forKey: "hud") as? Bool ?? false,
            noEsync: defaults.object(forKey: "noEsync") as? Bool ?? false,
            nativeWinmm: defaults.object(forKey: "nativeWinmm") as? Bool ?? true,
            nativeSteamAPI: defaults.object(forKey: "nativeSteamAPI") as? Bool ?? true,
            extraArguments: "",
            requiredFiles: ["eldenring.exe", "SeamlessCoop"],
            systemImage: "gamecontroller.fill"
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
            metalFX: false,
            hud: false,
            noEsync: false,
            nativeWinmm: false,
            nativeSteamAPI: false,
            extraArguments: "",
            requiredFiles: [],
            systemImage: "app.fill"
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
            metalFX: false,
            hud: false,
            noEsync: false,
            nativeWinmm: false,
            nativeSteamAPI: false,
            extraArguments: "",
            requiredFiles: [],
            systemImage: "square.grid.2x2.fill"
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
            metalFX: false,
            hud: false,
            noEsync: false,
            nativeWinmm: false,
            nativeSteamAPI: false,
            extraArguments: "",
            requiredFiles: [],
            systemImage: "gamecontroller.fill"
        )
    }
}

private struct PathSettings: Hashable {
    var gptkHome: String
    var prefixRoot: String
    var gamesRoot: String
    var externalRoot: String
    var steamLibrary: String

    init(config: ToolkitConfig) {
        gptkHome = config.gptkHome
        prefixRoot = config.prefixRoot
        gamesRoot = config.gamesRoot
        externalRoot = config.externalRoot
        steamLibrary = config.steamLibrary
    }
}

private struct DriveMap: Codable, Identifiable, Hashable {
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

private struct BackupItem: Identifiable, Hashable {
    let name: String
    let path: String
    let modified: Date

    var id: String { path }
}

private struct ToolkitConfig {
    let home: String
    let configPath: String
    let values: [String: String]
    let exists: Bool

    var gptkHome: String { expand(values["GPTK_HOME"] ?? "$HOME/GPTK") }
    var prefixRoot: String { expand(values["GPTK_PREFIX_ROOT"] ?? "$HOME/WinePrefixes") }
    var gamesRoot: String { expand(values["GPTK_GAMES_ROOT"] ?? "$HOME/Games") }
    var externalRoot: String { expand(values["GPTK_EXTERNAL_ROOT"] ?? "/Volumes/GameCoreApp") }
    var steamLibrary: String { expand(values["GPTK_STEAM_LIBRARY"] ?? "$GPTK_EXTERNAL_ROOT/SteamLibrary") }
    var logsPath: String { expand(values["GPTK_LOG_DIR"] ?? "$GPTK_HOME/logs") }
    var gptkWineHome: String { expand(values["GPTK_WINE_HOME"] ?? "$GPTK_HOME/apps/Game Porting Toolkit.app/Contents/Resources/wine") }
    var gptkRuntime: String { expand(values["GPTK_RUNTIME"] ?? "$GPTK_HOME/runtime") }
    var gptkDownloadPage: String { expand(values["GPTK_DOWNLOAD_PAGE"] ?? "https://developer.apple.com/games/game-porting-toolkit/") }
    var gptkLaunchPath: String { "\(home)/bin/gptk-launch" }
    var gptkSteamPath: String { "\(home)/bin/gptk-steam" }
    var gptkVCRunPath: String { "\(home)/bin/gptk-vcrun" }
    var gptkStubsPath: String { "\(home)/bin/gptk-stubs" }
    var hasToolkitScripts: Bool {
        FileManager.default.isExecutableFile(atPath: gptkLaunchPath)
            && FileManager.default.isExecutableFile(atPath: gptkSteamPath)
    }
    var hasWineRunner: Bool { detectedWineHome != nil }
    var hasD3DMetalRuntime: Bool {
        d3d12Candidates.contains { FileManager.default.fileExists(atPath: $0) }
    }
    var hasLocalGPTK: Bool {
        hasWineRunner && hasD3DMetalRuntime
    }
    var needsSetupGuide: Bool {
        !exists || !hasToolkitScripts || !hasLocalGPTK
    }

    private var detectedWineHome: String? {
        wineHomeCandidates.first {
            FileManager.default.isExecutableFile(atPath: "\($0)/bin/wine64")
        }
    }

    private var d3d12Candidates: [String] {
        uniqued(["\(gptkRuntime)/lib/wine/x86_64-windows/d3d12.dll"] + wineHomeCandidates.map {
            "\($0)/lib/wine/x86_64-windows/d3d12.dll"
        })
    }

    private var wineHomeCandidates: [String] {
        var candidates = [
            gptkWineHome,
            "\(gptkHome)/apps/Game Porting Toolkit.app/Contents/Resources/wine",
            "/Applications/Game Porting Toolkit.app/Contents/Resources/wine",
            "/Applications/Wine Stable.app/Contents/Resources/wine",
            "/Applications/Wine Staging.app/Contents/Resources/wine"
        ]

        let runnersURL = URL(fileURLWithPath: "\(gptkHome)/runners")
        if let runnerURLs = try? FileManager.default.contentsOfDirectory(
            at: runnersURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            candidates.append(contentsOf: runnerURLs.compactMap { url in
                guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                    return nil
                }
                return url.path
            })
        }

        return uniqued(candidates)
    }

    private func uniqued(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    static func load() -> ToolkitConfig {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let configPath = "\(home)/.rippermoon-gptk.env"
        let url = URL(fileURLWithPath: configPath)
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        return ToolkitConfig(
            home: home,
            configPath: configPath,
            values: parse(text),
            exists: FileManager.default.fileExists(atPath: configPath)
        )
    }

    private func expand(_ raw: String) -> String {
        var result = raw.strippedShellQuotes
        for _ in 0..<6 {
            result = result
                .replacingOccurrences(of: "${HOME}", with: home)
                .replacingOccurrences(of: "$HOME", with: home)

            for (key, value) in values {
                let expandedValue = value.strippedShellQuotes
                    .replacingOccurrences(of: "${HOME}", with: home)
                    .replacingOccurrences(of: "$HOME", with: home)
                result = result
                    .replacingOccurrences(of: "${\(key)}", with: expandedValue)
                    .replacingOccurrences(of: "$\(key)", with: expandedValue)
            }
        }
        return result
    }

    private static func parse(_ text: String) -> [String: String] {
        var output: [String: String] = [:]
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = String(rawLine).trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            if line.hasPrefix("export ") {
                line.removeFirst("export ".count)
            }
            guard let equalIndex = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<equalIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: equalIndex)...]).trimmingCharacters(in: .whitespaces)
            if !key.isEmpty {
                output[key] = value.strippedShellQuotes
            }
        }
        return output
    }
}

private extension DateFormatter {
    static let backupStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

private extension String {
    var shellQuoted: String {
        "'\(replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    var envEscaped: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    var strippedShellQuotes: String {
        var value = trimmingCharacters(in: .whitespacesAndNewlines)
        if value.count >= 2 {
            let first = value.first
            let last = value.last
            if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
                value.removeFirst()
                value.removeLast()
            }
        }
        return value
    }
}
