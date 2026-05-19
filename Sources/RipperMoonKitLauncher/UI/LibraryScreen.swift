import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct LibraryScreen: View {
    @EnvironmentObject private var model: LauncherModel
    @Binding var selection: SidebarSelection
    @State private var filter: LibraryFilter = .all
    @State private var query = ""
    @State private var featuredIndex = Int.random(in: 0 ..< 999)

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let featured {
                heroBanner(featured.profile, isLive: featured.live)
                    .id(featured.profile.id)
                    .transition(.opacity)
            }
            filterRow
            grid
            if !query.isEmpty && visible.isEmpty {
                emptyState
            }
        }
        .padding(EdgeInsets(top: 20, leading: 24, bottom: 40, trailing: 24))
        .task {
            // Auto-shuffle the spotlight every 5.5s while no game is running.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_500_000_000)
                if featured?.live == false {
                    withAnimation(.easeInOut(duration: 0.4)) { featuredIndex += 1 }
                }
            }
        }
    }

    /// Real games — everything except the Steam client.
    private var realGames: [GameProfile] {
        model.profiles.filter { !$0.isSteamApp }
    }

    /// The banner pick: a running game takes over; otherwise the shuffled spotlight.
    private var featured: (profile: GameProfile, live: Bool)? {
        if let live = realGames.first(where: { model.liveProfileIDs.contains($0.id) }) {
            return (live, true)
        }
        guard !realGames.isEmpty else { return nil }
        let index = ((featuredIndex % realGames.count) + realGames.count) % realGames.count
        return (realGames[index], false)
    }

    private func shuffleFeatured() {
        withAnimation(.easeInOut(duration: 0.2)) { featuredIndex += 1 }
    }

    private var visible: [GameProfile] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered = model.profiles.filter { p in
            let matchesQuery = q.isEmpty
                || p.name.lowercased().contains(q)
                || p.executable.lowercased().contains(q)
            let matchesFilter: Bool
            switch filter {
            case .all:    matchesFilter = true
            case .modded: matchesFilter = p.supportsModEngine
            case .steam:  matchesFilter = p.requiresSteam || p.isSteamApp || p.isSteamLibraryGame
            case .native: matchesFilter = !p.requiresSteam && !p.isSteamApp && !p.isSteamLibraryGame
            }
            return matchesQuery && matchesFilter
        }
        // The Steam client always holds the first grid slot.
        return filtered.filter { $0.isSteamApp } + filtered.filter { !$0.isSteamApp }
    }

    private func heroBanner(_ profile: GameProfile, isLive: Bool) -> some View {
        ZStack(alignment: .leading) {
            CoverArt(iconPath: profile.iconPath, label: profile.name,
                     seed: coverSeed(profile.name), corner: 22, showLabel: false)
            LinearGradient(
                colors: [Onyx.bgDeep.opacity(0.95), Onyx.bgDeep.opacity(0.2), .clear],
                startPoint: .leading, endPoint: .trailing
            )
            VStack(alignment: .leading, spacing: 9) {
                Text(isLive ? "Now Playing" : "Spotlight")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(isLive ? Onyx.good : Onyx.accent)
                    .textCase(.uppercase)
                Text(profile.name)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Onyx.text)
                Text(heroSubtitle(profile))
                    .font(.system(size: 12))
                    .foregroundStyle(Onyx.textDim)
                HStack(spacing: 8) {
                    LaunchStopButton(
                        isLive: isLive,
                        launchTitle: "Launch",
                        onLaunch: { model.launch(profile) },
                        onStop: { model.closeGame(profile) }
                    )
                    RMKButton(kind: .ghost, icon: "chevron.right", title: "Open") {
                        selection = .profile(profile.id)
                    }
                }
                .padding(.top, 4)
            }
            .padding(22)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(isLive ? Onyx.good.opacity(0.55) : Onyx.hairline,
                              lineWidth: isLive ? 1 : 0.75)
        }
        .overlay(alignment: .trailing) {
            BrandMark(size: 120).opacity(0.16).padding(.trailing, 28)
        }
        .overlay(alignment: .topTrailing) {
            heroCorner(isLive: isLive)
        }
        .contentShape(Rectangle())
        .onTapGesture { selection = .profile(profile.id) }
    }

    /// Idle banner shows a manual shuffle control; a live banner has none
    /// (the green border + "Now Playing" label carry the live state).
    @ViewBuilder private func heroCorner(isLive: Bool) -> some View {
        if !isLive {
            Button { shuffleFeatured() } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Onyx.text)
                    .frame(width: 30, height: 30)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay { Circle().strokeBorder(Onyx.hairline2, lineWidth: 0.75) }
            }
            .buttonStyle(.plain)
            .help("Shuffle the spotlight")
            .padding(14)
        }
    }

    private func heroSubtitle(_ p: GameProfile) -> String {
        if p.isSteamApp { return "Steam client" }
        if p.supportsModEngine { return "Modded · ModEngine 2 ready" }
        if p.requiresSteam { return "Uses Steam · \(p.prefix)" }
        return "\(p.prefix) · \(p.winver)"
    }

    private var filterRow: some View {
        HStack(spacing: 14) {
            Text("Library")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Onyx.text)
            Text(query.isEmpty
                 ? "\(model.profiles.count) games & apps"
                 : "\(visible.count) of \(model.profiles.count)")
                .font(.system(size: 11.5))
                .foregroundStyle(Onyx.textMute)
            Spacer()
            searchField
            HStack(spacing: 6) {
                ForEach(LibraryFilter.allCases, id: \.self) { f in
                    RMKChip(title: f.rawValue, active: filter == f) { filter = f }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Onyx.textDim)
            TextField("Search games", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(Onyx.text)
                .frame(width: 130)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Onyx.textMute)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Onyx.surface2, in: Capsule(style: .continuous))
        .overlay { Capsule(style: .continuous).strokeBorder(Onyx.hairline2, lineWidth: 0.75) }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(visible) { profile in
                LibraryTile(
                    profile: profile,
                    isLive: model.liveProfileIDs.contains(profile.id),
                    onOpen: { selection = .profile(profile.id) },
                    onTogglePower: { on in
                        if on {
                            model.launch(profile)
                        } else if profile.isSteamApp {
                            model.stopSteam()
                        } else {
                            model.closeGame(profile)
                        }
                    }
                )
            }
            if query.isEmpty {
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

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 20))
                .foregroundStyle(Onyx.textMute)
            Text("No games match “\(query)”")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Onyx.text)
            Text("Try a different name, or clear the search.")
                .font(.system(size: 11.5))
                .foregroundStyle(Onyx.textMute)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Onyx.hairline2, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        }
    }
}

struct LibraryTile: View {
    let profile: GameProfile
    var isLive: Bool = false
    var onOpen: () -> Void = {}
    var onTogglePower: (Bool) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            CoverArt(iconPath: profile.iconPath, label: profile.name,
                     seed: coverSeed(profile.name), corner: 9)
                .frame(height: 88)
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Onyx.text)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(Onyx.textMute)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                PowerToggle(isOn: isLive, label: profile.name) { onTogglePower($0) }
            }
            .padding(.horizontal, 3)
            .padding(.bottom, 3)
        }
        .padding(7)
        .background(Onyx.surface, in: RoundedRectangle(cornerRadius: Onyx.tileRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Onyx.tileRadius, style: .continuous)
                .strokeBorder(isLive ? Onyx.good.opacity(0.45) : Onyx.hairline,
                              lineWidth: 0.75)
        }
        .contentShape(Rectangle())
        .onTapGesture { onOpen() }
    }

    private var subtitle: String {
        if profile.isSteamApp { return isLive ? "Steam client · running" : "Steam client" }
        if let id = profile.steamAppID, !id.isEmpty { return "Steam · AppID \(id)" }
        if profile.requiresSteam { return "Uses Steam" }
        return profile.prefix
    }
}

/// Power launch button used on every library tile — glows red when the app is
/// idle, green when it is running. The glow doubles as the live indicator.
struct PowerToggle: View {
    var isOn: Bool
    var label: String = ""
    var action: (Bool) -> Void

    private var tint: Color { isOn ? Onyx.good : Onyx.accent }

    var body: some View {
        Button { action(!isOn) } label: {
            Image(systemName: "power")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(Circle().fill(tint.opacity(0.16)))
                .overlay { Circle().strokeBorder(tint.opacity(0.55), lineWidth: 1) }
                .shadow(color: tint.opacity(0.85), radius: 5)
                .shadow(color: tint.opacity(0.45), radius: 10)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isOn)
        .help(isOn ? "Stop \(label)" : "Launch \(label)")
    }
}

struct AddGameTile: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(Onyx.surface, in: Circle())
                .overlay { Circle().strokeBorder(Onyx.hairline, lineWidth: 0.75) }
            Text("Add Game")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(Onyx.textDim)
        .frame(maxWidth: .infinity, minHeight: 138)
        .background(Onyx.surface.opacity(0.4),
                    in: RoundedRectangle(cornerRadius: Onyx.tileRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Onyx.tileRadius, style: .continuous)
                .strokeBorder(Onyx.hairline2, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let detail: String
    var body: some View {
        Card(title: title, icon: "questionmark.folder.fill") {
            Text(detail)
                .font(.system(size: 12.5))
                .foregroundStyle(Onyx.textDim)
        }
    }
}
