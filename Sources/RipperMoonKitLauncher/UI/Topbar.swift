import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RMKTopbar: View {
    @EnvironmentObject private var model: LauncherModel
    @Binding var selection: SidebarSelection
    @Binding var sidebarOpen: Bool

    var body: some View {
        HStack(spacing: 14) {
            Color.clear.frame(width: sidebarOpen ? 0 : 64, height: 1)

            Button {
                sidebarOpen.toggle()
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 13))
                    .foregroundStyle(Onyx.textDim)
                    .frame(width: 28, height: 28)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Onyx.hairline, lineWidth: 0.75)
                    }
            }
            .buttonStyle(.plain)

            icon

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 7) {
                    if breadcrumb != nil {
                        Text(breadcrumb!)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Onyx.textMute)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(Onyx.textMute)
                    }
                    Text(title)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(Onyx.text)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Onyx.textMute)
                        .lineLimit(1)
                }
            }

            Spacer()

            RMKButton(kind: .ghost, icon: "arrow.clockwise", title: "Refresh", small: true) {
                model.reload()
            }
            Button {
                let profile = model.addProfile()
                selection = .profile(profile.id)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Onyx.accentInk)
                    .frame(width: 30, height: 30)
                    .background(Onyx.accent, in: Circle())
                    .shadow(color: Onyx.glow.opacity(0.4), radius: 7, y: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(minHeight: 58)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) { Rectangle().fill(Onyx.hairline).frame(height: 1) }
    }

    private var currentProfile: GameProfile? {
        guard case .profile(let id) = selection else { return nil }
        return model.profiles.first { $0.id == id }
    }

    @ViewBuilder private var icon: some View {
        if let profile = currentProfile {
            CoverArt(iconPath: profile.iconPath, label: profile.name,
                     seed: coverSeed(profile.name), corner: 7, showLabel: false)
                .frame(width: 26, height: 26)
        } else {
            BrandMark(size: 24, glow: true)
        }
    }

    private var breadcrumb: String? {
        if case .profile = selection { return "Library" }
        return nil
    }

    private var title: String {
        switch selection {
        case .library:  return "RipperMoonKit"
        case .backups:  return "Backups"
        case .settings: return "Settings"
        case .profile:  return currentProfile?.name ?? "Profile"
        }
    }

    private var subtitle: String? {
        switch selection {
        case .settings: return model.config.configPath
        default:        return "Macs can't game? Cute. Reap anyway."
        }
    }
}

// MARK: - Library

/// Primary banner button that crossfades between Launch and Stop with the
/// profile's live state — shared by the Library banner and the in-profile hero.
struct LaunchStopButton: View {
    var isLive: Bool
    var launchTitle: String = "Launch"
    var onLaunch: () -> Void
    var onStop: () -> Void

    var body: some View {
        ZStack {
            if isLive {
                RMKButton(kind: .primary, icon: "stop.fill", title: "Stop", action: onStop)
                    .transition(.opacity)
            } else {
                RMKButton(kind: .primary, icon: "power", title: launchTitle, action: onLaunch)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isLive)
    }
}

enum LibraryFilter: String, CaseIterable {
    case all = "All", modded = "Modded", steam = "Steam", native = "Native"
}
