import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RMKSidebar: View {
    @EnvironmentObject private var model: LauncherModel
    @Binding var selection: SidebarSelection
    @Binding var darkOverride: Bool?
    @Environment(\.colorScheme) private var scheme
    @State private var editingPins = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 30)

            HStack(spacing: 10) {
                BrandMark(size: 51, glow: true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("RipperMoonKit")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Onyx.text)
                    Text("v\(rmkAppVersion) · Onyx")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Onyx.textMute)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            sectionLabel("Library")
            navItem(.library, "Games & Apps", "square.grid.2x2.fill")

            sectionLabel("Toolkit")
            navItem(.backups, "Backups", "clock.arrow.circlepath")
            navItem(.settings, "Settings", "gearshape.fill")
            UpdateNoticeBanner(selection: $selection)

            if model.profiles.isEmpty {
                Spacer(minLength: 12)
            } else {
                pinnedHeader
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(model.pinnedProfiles) { profile in
                            pinnedRow(profile)
                        }
                        if model.pinnedProfiles.isEmpty && !editingPins {
                            emptyPinHint
                        }
                        if editingPins {
                            addPinControl
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: .infinity)
                .scrollIndicators(.hidden)
            }

            HelpButton()
            KofiSupport()
            FeedbackButton(selection: selection)
            footer
        }
        .frame(width: 224)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Onyx.hairline).frame(width: 1)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(Onyx.textMute)
            .textCase(.uppercase)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)
    }

    private func navItem(_ target: SidebarSelection, _ label: String, _ icon: String) -> some View {
        let active = selection == target
        return Button {
            selection = target
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(active ? Onyx.accentInk : Onyx.accent)
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(active ? Onyx.accentInk : Onyx.text)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(active ? Onyx.accent : .clear,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }

    private var pinnedHeader: some View {
        HStack {
            Text("Pinned")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Onyx.textMute)
                .textCase(.uppercase)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { editingPins.toggle() }
            } label: {
                Text(editingPins ? "Done" : "Edit")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(editingPins ? Onyx.accent : Onyx.textMute)
            }
            .buttonStyle(.plain)
            .help(editingPins ? "Finish editing pins" : "Add or remove pinned games")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    private func pinnedRow(_ profile: GameProfile) -> some View {
        let active = selection == .profile(profile.id) && !editingPins
        return HStack(spacing: 9) {
            CoverArt(iconPath: profile.iconPath, label: profile.name,
                     seed: coverSeed(profile.name), corner: 5, showLabel: false)
                .frame(width: 20, height: 20)
            Text(profile.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Onyx.text)
                .lineLimit(1)
            Spacer(minLength: 0)
            if editingPins {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { model.unpinProfile(profile.id) }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Onyx.accent)
                }
                .buttonStyle(.plain)
                .help("Unpin \(profile.name)")
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(active ? Onyx.surface2 : .clear,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            if !editingPins { selection = .profile(profile.id) }
        }
    }

    private var emptyPinHint: some View {
        Text("Tap Edit to pin games here.")
            .font(.system(size: 10.5))
            .foregroundStyle(Onyx.textMute)
            .padding(.horizontal, 19)
            .padding(.vertical, 6)
    }

    @ViewBuilder private var addPinControl: some View {
        if model.unpinnedProfiles.isEmpty {
            Text("All games pinned.")
                .font(.system(size: 10.5))
                .foregroundStyle(Onyx.textMute)
                .padding(.horizontal, 19)
                .padding(.vertical, 6)
        } else {
            Menu {
                ForEach(model.unpinnedProfiles) { profile in
                    Button(profile.name) {
                        withAnimation(.easeInOut(duration: 0.15)) { model.pinProfile(profile.id) }
                    }
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(Onyx.accent)
                        .frame(width: 20)
                    Text("Add game")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Onyx.accent)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .padding(.horizontal, 8)
            .padding(.top, 2)
        }
    }

    private var footer: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "moonphase.waxing.gibbous.inverse")
                    .font(.system(size: 14))
                    .foregroundStyle(Onyx.accent)
                Text("Waxing Gibbous")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Onyx.textDim)
                Spacer()
            }
            Rectangle().fill(Onyx.hairline).frame(height: 1)
            HStack(spacing: 6) {
                Text("Appearance")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.3)
                    .foregroundStyle(Onyx.textMute)
                    .textCase(.uppercase)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { scheme == .dark },
                    set: { darkOverride = $0 }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .tint(Onyx.accent)
            }
        }
        .padding(12)
        .background(Onyx.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Onyx.hairline, lineWidth: 0.75)
        }
        .padding(10)
    }
}

struct UpdateNoticeBanner: View {
    @EnvironmentObject private var model: LauncherModel
    @Binding var selection: SidebarSelection

    var body: some View {
        if let notice = model.updateNotice {
            Button {
                selection = .settings
            } label: {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Onyx.accent)
                        Text("Update Available")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Onyx.text)
                        Spacer(minLength: 0)
                    }
                    Text("\(notice.version) is on GitHub. Go to Settings > Maintenance > Update From GitHub.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Onyx.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(Onyx.surface2, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Onyx.accent.opacity(0.35), lineWidth: 0.9)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .help("Open Settings to update RipperMoonKit from GitHub.")
        }
    }
}

// MARK: - Topbar

/// Sidebar support prompt — a plain one-liner and a bordered Ko-fi button.
struct KofiSupport: View {
    private static let logo = AppResource.image(named: "kofi_logo")

    var body: some View {
        VStack(spacing: 9) {
            Text("Not a big ask — but $5 helps the dev keep this app alive.")
                .font(.system(size: 10.5))
                .foregroundStyle(Onyx.textMute)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                if let url = URL(string: "https://ko-fi.com/moontheripper") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Group {
                    if let logo = KofiSupport.logo {
                        Image(nsImage: logo).resizable().scaledToFit()
                    } else {
                        Text("Support on Ko-fi")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.black)
                    }
                }
                .frame(height: 13)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.22), radius: 2, y: 0.5)
            }
            .buttonStyle(.plain)
            .help("Support the developer on Ko-fi")
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 2)
    }
}

/// Creates a structured tester report without embedding GitHub credentials in the app.
struct FeedbackButton: View {
    @EnvironmentObject private var model: LauncherModel
    let selection: SidebarSelection

    var body: some View {
        Button {
            model.reportTestResult(for: selectedProfile)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Onyx.accent)
                Text("Report Test Result")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Onyx.text)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(Onyx.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Onyx.hairline, lineWidth: 0.75)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .help("Copy a structured tester report and open a prefilled GitHub issue.")
    }

    private var selectedProfile: GameProfile? {
        guard case let .profile(id) = selection else { return nil }
        return model.profiles.first { $0.id == id }
    }
}

/// Sidebar entry that opens the bundled how-to documentation.
struct HelpButton: View {
    @EnvironmentObject private var model: LauncherModel

    var body: some View {
        Button {
            model.openHelpDocs()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "book.fill")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Onyx.accent)
                Text("Help & Docs")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Onyx.text)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Onyx.textMute)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(Onyx.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Onyx.hairline, lineWidth: 0.75)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .help("Open the RipperMoonKit guide — setup, adding games, and launching.")
    }
}
