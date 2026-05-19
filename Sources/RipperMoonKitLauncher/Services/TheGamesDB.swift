import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - TheGamesDB

/// Minimal TheGamesDB client — used to fetch box-art covers for game profiles.
/// The API key is supplied by the caller; it is never embedded in source.
enum TheGamesDB {
    struct Match: Identifiable, Hashable {
        let id: Int
        let title: String
        let year: String?
        let thumbURL: URL?
        let fullURL: URL?
    }

    enum ServiceError: LocalizedError {
        case noKey, badResponse, http(Int)
        var errorDescription: String? {
            switch self {
            case .noKey:        return "No TheGamesDB API key. Add one in Settings › Cover Art."
            case .badResponse:  return "TheGamesDB returned an unexpected response."
            case .http(let c):  return "TheGamesDB request failed (HTTP \(c))."
            }
        }
    }

    private struct SearchResponse: Decodable {
        struct GamesBlock: Decodable { let games: [Game] }
        struct Game: Decodable { let id: Int; let gameTitle: String; let releaseDate: String? }
        struct IncludeBlock: Decodable { let boxart: Boxart }
        struct Boxart: Decodable { let baseUrl: BaseURL; let data: [String: [Art]] }
        struct BaseURL: Decodable { let thumb: String; let original: String }
        struct Art: Decodable { let type: String; let side: String?; let filename: String }
        let data: GamesBlock
        let include: IncludeBlock?
    }

    /// Searches games by name and resolves a front box-art image for each result.
    static func search(name: String, apiKey: String) async throws -> [Match] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard !apiKey.isEmpty else { throw ServiceError.noKey }

        var comps = URLComponents(string: "https://api.thegamesdb.net/v1.1/Games/ByGameName")!
        comps.queryItems = [
            URLQueryItem(name: "apikey", value: apiKey),
            URLQueryItem(name: "name", value: trimmed),
            URLQueryItem(name: "include", value: "boxart"),
        ]
        guard let url = comps.url else { throw ServiceError.badResponse }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.badResponse }
        guard http.statusCode == 200 else { throw ServiceError.http(http.statusCode) }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(SearchResponse.self, from: data)
        let boxart = decoded.include?.boxart

        return decoded.data.games.map { game in
            let arts = boxart?.data[String(game.id)] ?? []
            let front = arts.first { ($0.side ?? "") == "front" && $0.type == "boxart" }
                ?? arts.first { $0.type == "boxart" }
            let thumb = front.flatMap { art in
                (boxart?.baseUrl.thumb).flatMap { URL(string: $0 + art.filename) }
            }
            let full = front.flatMap { art in
                (boxart?.baseUrl.original).flatMap { URL(string: $0 + art.filename) }
            }
            let year = game.releaseDate?.split(separator: "-").first.map(String.init)
            return Match(id: game.id, title: game.gameTitle, year: year,
                         thumbURL: thumb, fullURL: full)
        }
    }

    /// Downloads raw image bytes for a resolved cover.
    static func download(_ url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.badResponse }
        guard http.statusCode == 200 else { throw ServiceError.http(http.statusCode) }
        return data
    }
}

// MARK: - Cover search sheet
