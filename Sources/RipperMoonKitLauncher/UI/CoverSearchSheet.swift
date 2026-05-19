import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct CoverSearchSheet: View {
    @EnvironmentObject private var model: LauncherModel
    @Environment(\.dismiss) private var dismiss
    @Binding var profile: GameProfile

    @State private var query: String
    @State private var results: [TheGamesDB.Match] = []
    @State private var status: Status = .start
    @State private var applyingID: Int?

    private enum Status: Equatable { case start, loading, empty, failed(String), ready }

    init(profile: Binding<GameProfile>) {
        _profile = profile
        _query = State(initialValue: profile.wrappedValue.name)
    }

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            Rectangle().fill(Onyx.hairline).frame(height: 1)
            content
        }
        .background(Onyx.bg)
        .onAppear { if results.isEmpty { runSearch() } }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 16))
                .foregroundStyle(Onyx.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("Find Cover Art")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Onyx.text)
                Text("TheGamesDB")
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

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(Onyx.textDim)
                TextField("Game title", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Onyx.text)
                    .onSubmit { runSearch() }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(Onyx.bgDeep, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Onyx.hairline, lineWidth: 0.75)
            }
            RMKButton(kind: .primary, icon: "magnifyingglass", title: "Search") { runSearch() }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder private var content: some View {
        switch status {
        case .start:
            stateView {
                Text("Search for a game to pick its cover.")
                    .font(.system(size: 12)).foregroundStyle(Onyx.textMute)
            }
        case .loading:
            stateView {
                ProgressView().controlSize(.small)
                Text("Searching TheGamesDB…")
                    .font(.system(size: 12)).foregroundStyle(Onyx.textMute)
            }
        case .empty:
            stateView {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20)).foregroundStyle(Onyx.textMute)
                Text("No matches for “\(query)”.")
                    .font(.system(size: 12)).foregroundStyle(Onyx.textMute)
            }
        case .failed(let message):
            stateView {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 20)).foregroundStyle(Onyx.warn)
                Text(message)
                    .font(.system(size: 12)).foregroundStyle(Onyx.textMute)
                    .multilineTextAlignment(.center)
            }
        case .ready:
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(results) { resultTile($0) }
                }
                .padding(16)
            }
        }
    }

    private func stateView<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 10) { content() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
    }

    private func resultTile(_ match: TheGamesDB.Match) -> some View {
        Button { apply(match) } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    Rectangle().fill(Onyx.surface2)
                    AsyncImage(url: match.thumbURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            Image(systemName: "photo").foregroundStyle(Onyx.textMute)
                        default:
                            ProgressView().controlSize(.small)
                        }
                    }
                    if applyingID == match.id {
                        Color.black.opacity(0.5)
                        ProgressView().controlSize(.small)
                    }
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(match.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Onyx.text)
                    .lineLimit(1)
                Text(match.year ?? "Unknown year")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Onyx.textMute)
            }
            .padding(8)
            .background(Onyx.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Onyx.hairline, lineWidth: 0.75)
            }
        }
        .buttonStyle(.plain)
        .disabled(applyingID != nil || match.fullURL == nil)
    }

    private func runSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { status = .start; return }
        status = .loading
        Task {
            do {
                let found = try await TheGamesDB.search(name: q, apiKey: model.tgdbAPIKey)
                results = found
                status = found.isEmpty ? .empty : .ready
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }

    private func apply(_ match: TheGamesDB.Match) {
        guard match.fullURL != nil else { return }
        applyingID = match.id
        Task {
            await model.saveCover(match, for: profile.id)
            applyingID = nil
            dismiss()
        }
    }
}
