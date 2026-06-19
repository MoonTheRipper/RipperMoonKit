import SwiftUI

/// Lists games already installed in the Windows Steam library and adds the
/// chosen one as a Steam-managed profile (one-click launch, auto-starts Steam).
struct AddSteamGameSheet: View {
    @EnvironmentObject private var model: LauncherModel
    @Environment(\.dismiss) private var dismiss
    var onAdded: (GameProfile) -> Void

    @State private var games: [InstalledSteamGame] = []
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Onyx.hairline).frame(height: 1)
            content
        }
        .frame(width: 460, height: 520)
        .background(Onyx.bg)
        .onAppear {
            guard !loaded else { return }
            games = model.installedSteamGames()
            loaded = true
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Onyx.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("Add Steam Game")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Onyx.text)
                Text("Installed in your Steam library")
                    .font(.system(size: 11))
                    .foregroundStyle(Onyx.textMute)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Onyx.textDim)
                    .frame(width: 24, height: 24)
                    .background(Onyx.surface2, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    @ViewBuilder private var content: some View {
        if games.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "tray")
                    .font(.system(size: 20)).foregroundStyle(Onyx.textMute)
                Text("No installed Steam games found.")
                    .font(.system(size: 12)).foregroundStyle(Onyx.textMute)
                Text("Install a game in Steam first, then reopen this. Games on an unplugged external drive are skipped.")
                    .font(.system(size: 11)).foregroundStyle(Onyx.textMute)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(games) { row($0) }
                }
                .padding(16)
            }
        }
    }

    private func row(_ game: InstalledSteamGame) -> some View {
        let added = model.steamGameAlreadyAdded(game.appID)
        return HStack(spacing: 12) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 13))
                .foregroundStyle(Onyx.accent)
                .frame(width: 30, height: 30)
                .background(Onyx.surface2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(game.name)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Onyx.text)
                    .lineLimit(1)
                Text("App \(game.appID)")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Onyx.textMute)
            }
            Spacer(minLength: 8)
            if added {
                Label("Added", systemImage: "checkmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Onyx.good)
            } else {
                RMKButton(kind: .primary, icon: "plus", title: "Add", small: true) {
                    let profile = model.addSteamGame(game)
                    onAdded(profile)
                    dismiss()
                }
            }
        }
        .padding(10)
        .background(Onyx.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Onyx.hairline, lineWidth: 0.75)
        }
    }
}
