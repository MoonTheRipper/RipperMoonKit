import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Setup guide

struct SetupGuideView: View {
    @EnvironmentObject private var model: LauncherModel
    @State private var showAdvanced = false

    private var checks: [SetupCheck] { model.setupChecks }
    private var coreChecks: [SetupCheck] { checks.filter { !$0.isOptional } }
    /// "Ready to game" depends only on the required pieces — Steam is optional.
    private var coreReady: Bool { coreChecks.allSatisfy(\.isOK) }
    private var readyCount: Int { coreChecks.filter(\.isOK).count }
    private var gptkDownloadURL: URL {
        URL(string: model.config.gptkDownloadPage) ?? URL(string: "https://developer.apple.com/games/game-porting-toolkit/")!
    }

    var body: some View {
        Group {
            if coreReady {
                successView
            } else if model.awaitingGPTKDownload && !model.config.hasLocalGPTK {
                gptkDownloadView
            } else {
                progressView
            }
        }
        .padding(24)
        .background(Onyx.bg)
        .task {
            // Auto-recheck: the checklist ticks itself off, no button needed.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if Task.isCancelled { break }
                model.refreshSetupChecks()
            }
        }
    }

    // MARK: - In-progress

    private var progressView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                BrandMark(size: 52, glow: true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Setting up RipperMoonKit")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Onyx.text)
                    Text("One click installs everything. macOS asks for your Mac password once, and Apple's Game Porting Toolkit is the only file you download yourself.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Onyx.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Text("\(readyCount) of \(coreChecks.count) ready")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Onyx.textMute)
                    .fixedSize()
                ProgressView(value: Double(readyCount), total: Double(coreChecks.count))
                    .tint(Onyx.accent)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(checks) { check in
                    SetupRow(check: check)
                }
            }
            .padding(14)
            .background(Onyx.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Onyx.hairline, lineWidth: 0.75)
            }

            if !model.config.hasLocalGPTK {
                gptkNotice
            }

            if model.guidedSetupRunning {
                HStack(alignment: .top, spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Setup is running in the Terminal window. Each item above ticks off on its own as it installs. The app only moves forward after GPTK 3.0 is mounted, copied, and verified.")
                        .font(.system(size: 12))
                        .foregroundStyle(Onyx.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            RMKButton(kind: .primary, icon: "sparkles",
                      title: model.guidedSetupRunning ? "Restart Setup" : "Set Up RipperMoonKit") {
                model.startFirstRunSetup()
            }

            DisclosureGroup(isExpanded: $showAdvanced) {
                FlowLayout(spacing: 8) {
                    RMKButton(kind: .ghost, icon: "arrow.down.circle", title: "Prepare Source", small: true) {
                        model.prepareToolkitSource()
                    }
                    RMKButton(kind: .ghost, icon: "square.and.arrow.down", title: "Install Toolkit", small: true) {
                        model.installToolkit()
                    }
                    RMKButton(kind: .ghost, icon: "externaldrive.badge.plus", title: "Begin GPTK Install", small: true) {
                        model.beginGPTKInstall()
                    }
                }
                .padding(.top, 10)
            } label: {
                Text("Advanced — run individual steps")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Onyx.textMute)
            }
            .tint(Onyx.textDim)

            HStack {
                Spacer()
                Button("Set up later") { model.deferSetup() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(Onyx.textMute)
                Spacer()
            }
        }
    }

    private var gptkNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("One step needs you", systemImage: "person.badge.key.fill")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Onyx.text)
            Text("Download Game Porting Toolkit 3.0 from Apple Developer. Sign in with a free Apple Developer account, download the evaluation environment DMG, then open it so it mounts. RipperMoonKit will stay here until GPTK 3.0 is processed and verified.")
                .font(.system(size: 11.5))
                .foregroundStyle(Onyx.textDim)
                .fixedSize(horizontal: false, vertical: true)
            Link(destination: gptkDownloadURL) {
                Text("Open Apple's Game Porting Toolkit 3.0 download page")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Onyx.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Onyx.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Onyx.accent.opacity(0.4), lineWidth: 0.75)
        }
    }

    private var gptkDownloadView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                BrandMark(size: 52, glow: true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Download Game Porting Toolkit 3.0")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Onyx.text)
                    Text("This is the only required file RipperMoonKit cannot bundle. Download it from Apple, open the DMG, then come back here. Installation will not start until the GPTK download or mount is detected.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Onyx.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("What to do now", systemImage: "externaldrive.badge.plus")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Onyx.text)
                Text("1. Sign in with a free Apple Developer account.\n2. Download Game Porting Toolkit 3.0.\n3. Open the downloaded DMG so it appears in Finder.\n4. Return here when the button below becomes available.")
                    .font(.system(size: 12))
                    .foregroundStyle(Onyx.textDim)
                    .fixedSize(horizontal: false, vertical: true)
                Link(destination: gptkDownloadURL) {
                    Text("Open Apple's Game Porting Toolkit 3.0 download page")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Onyx.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Onyx.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Onyx.accent.opacity(0.4), lineWidth: 0.75)
            }

            Label(model.config.gptkInstallMediaStatus, systemImage: model.config.hasGPTKInstallMedia ? "checkmark.circle.fill" : "clock.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(model.config.hasGPTKInstallMedia ? Onyx.good : Onyx.textDim)

            RMKButton(
                kind: .primary,
                icon: "externaldrive.badge.checkmark",
                title: model.config.hasGPTKInstallMedia ? "Begin GPTK Install" : "Waiting for GPTK Download",
                disabled: !model.config.hasGPTKInstallMedia
            ) {
                model.beginGPTKInstall()
            }

            HStack {
                Spacer()
                Button("Set up later") { model.deferSetup() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(Onyx.textMute)
                Spacer()
            }
        }
        .onAppear {
            model.openGPTKPageForCurrentSetupIfNeeded()
        }
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: 16) {
            BrandMark(size: 64, glow: true)

            VStack(spacing: 5) {
                Text("You're all set")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Onyx.text)
                Text(model.steamReady
                     ? "Steam is installed and RipperMoonKit is ready. Sign into Steam when a game needs it, then add copied Windows game folders and cover art."
                     : model.steamInstallPending
                     ? "RipperMoonKit is ready. Steam is installing in the background, so you can set game folders and cover art while it finishes."
                     : "Core setup is ready. Install Steam from the Steam profile before Steam-dependent games, then add copied Windows game folders and cover art.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Onyx.textDim)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            RMKButton(kind: .primary, icon: "gamecontroller.fill", title: "Start Gaming") {
                model.finishSetup()
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("NEXT STEPS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Onyx.textMute)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if model.steamReady {
                    optionalCard(
                        icon: "person.crop.circle.badge.checkmark",
                        title: "Sign into Steam",
                        detail: "Open the Steam profile when you need Steam, sign in, and keep it running for Steam-dependent games.",
                        action: "Steam Profile"
                    ) { model.goToSteamSetup() }
                } else if model.steamInstallPending {
                    optionalCard(
                        icon: "clock.arrow.circlepath",
                        title: "Steam is installing",
                        detail: "Leave the background install alone. In the meantime, set paths, add game profiles, and add cover art.",
                        action: "Steam Profile"
                    ) { model.goToSteamSetup() }
                } else {
                    optionalCard(
                        icon: "arrow.down.app.fill",
                        title: "Finish Steam setup",
                        detail: "Install Windows Steam to play your Steam library. Non-Steam games don't need it.",
                        action: "Open Steam"
                    ) { model.goToSteamSetup() }
                }
                optionalCard(
                    icon: "folder.fill",
                    title: "Set your games folder",
                    detail: "Use a copied, already-installed Windows game folder. Do not point the app at installer files.",
                    action: "Settings"
                ) { model.openSetupRelatedSettings() }
                optionalCard(
                    icon: "photo.fill",
                    title: "Add cover art",
                    detail: "Add a free TheGamesDB API key to pull box-art for your game tiles.",
                    action: "Settings"
                ) { model.openSetupRelatedSettings() }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private func optionalCard(icon: String, title: String, detail: String,
                              action: String, perform: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Onyx.accent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Onyx.text)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Onyx.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            RMKButton(kind: .ghost, title: action, small: true, action: perform)
        }
        .padding(12)
        .background(Onyx.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Onyx.hairline, lineWidth: 0.75)
        }
    }
}

struct SetupRow: View {
    let check: SetupCheck

    private var statusLabel: String {
        if check.isOK { return "Ready" }
        return check.isOptional ? "Optional" : "Pending"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: check.isOK ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(check.isOK ? Onyx.good : Onyx.textMute)
            VStack(alignment: .leading, spacing: 2) {
                Text(check.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Onyx.text)
                Text(check.explanation)
                    .font(.system(size: 11))
                    .foregroundStyle(Onyx.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text(statusLabel)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(check.isOK ? Onyx.good : Onyx.textMute)
        }
        .help(check.detail)
    }
}

/// Persistent bar shown when setup is unfinished and the window is closed.
struct SetupBanner: View {
    @EnvironmentObject private var model: LauncherModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .bold))
            Text("Setup isn't finished — games can't launch yet.")
                .font(.system(size: 11.5, weight: .semibold))
            Spacer()
            Button { model.reopenSetupGuide() } label: {
                Text("Finish Setup")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Onyx.accent)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 4)
                    .background(Color.white, in: Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Onyx.accentInk)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Onyx.accent)
    }
}
