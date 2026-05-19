import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ToolkitConfig {
    let home: String
    let configPath: String
    let values: [String: String]
    let exists: Bool

    var gptkHome: String { expand(values["GPTK_HOME"] ?? "$HOME/GPTK") }
    var prefixRoot: String { expand(values["GPTK_PREFIX_ROOT"] ?? "$HOME/WinePrefixes") }
    var gamesRoot: String { expand(values["GPTK_GAMES_ROOT"] ?? "$HOME/Games") }
    var externalRoot: String { expand(values["GPTK_EXTERNAL_ROOT"] ?? "$HOME/Library/Application Support/RipperMoonKit") }
    var steamLibrary: String { expand(values["GPTK_STEAM_LIBRARY"] ?? "$GPTK_EXTERNAL_ROOT/SteamLibrary") }
    var logsPath: String { expand(values["GPTK_LOG_DIR"] ?? "$GPTK_HOME/logs") }
    var gptkAppPath: String { expand(values["GPTK_APP_PATH"] ?? "$GPTK_HOME/apps/Game Porting Toolkit.app") }
    var localGPTKWineHome: String { "\(gptkAppPath)/Contents/Resources/wine" }
    var gptkWineHome: String { expand(values["GPTK_WINE_HOME"] ?? "$GPTK_HOME/apps/Game Porting Toolkit.app/Contents/Resources/wine") }
    var effectiveWineHome: String { detectedWineHome ?? gptkWineHome }
    var toolWineHome: String {
        toolWineHomeCandidates.first(where: hasWineExecutable) ?? effectiveWineHome
    }
    var gptkRuntime: String { expand(values["GPTK_RUNTIME"] ?? "$GPTK_HOME/runtime") }
    var gptkDownloadDir: String { expand(values["GPTK_DOWNLOAD_DIR"] ?? "$HOME/Downloads") }
    var gptkDownloadPage: String { expand(values["GPTK_DOWNLOAD_PAGE"] ?? "https://developer.apple.com/games/game-porting-toolkit/") }
    var steamSetupPath: String {
        expand(values["STEAM_SETUP_PATH"] ?? "$HOME/Library/Application Support/RipperMoonKit/Downloads/SteamSetup.exe")
    }
    var gptkLaunchPath: String { "\(home)/bin/gptk-launch" }
    var gptkSteamPath: String { "\(home)/bin/gptk-steam" }
    var gptkVCRunPath: String { "\(home)/bin/gptk-vcrun" }
    var gptkDotNet6Path: String { "\(home)/bin/gptk-dotnet6" }
    var gptkStubsPath: String { "\(home)/bin/gptk-stubs" }
    var hasToolkitScripts: Bool {
        FileManager.default.isExecutableFile(atPath: gptkLaunchPath)
            && FileManager.default.isExecutableFile(atPath: gptkSteamPath)
    }
    var hasWineRunner: Bool { detectedWineHome != nil }
    var hasLocalWineRunner: Bool {
        FileManager.default.isExecutableFile(atPath: "\(localGPTKWineHome)/bin/wine64")
    }
    var hasD3DMetalRuntime: Bool {
        d3d12Candidates.contains { FileManager.default.fileExists(atPath: $0) }
    }
    var hasLocalD3DMetalRuntime: Bool {
        FileManager.default.fileExists(atPath: "\(gptkRuntime)/lib/wine/x86_64-windows/d3d12.dll")
    }
    var hasLocalGPTK: Bool {
        hasLocalWineRunner && hasLocalD3DMetalRuntime
    }
    var hasGPTKInstallMedia: Bool {
        downloadedGPTKDmgPath != nil
            || mountedGPTKRuntimeSource != nil
            || hasLocalD3DMetalRuntime
    }
    var gptkInstallMediaStatus: String {
        if hasLocalGPTK {
            return "GPTK is already installed locally."
        }
        if let runtime = mountedGPTKRuntimeSource {
            if let app = mountedGPTKAppSource {
                return "GPTK runtime and app source detected: \(runtime) + \(app)"
            }
            return "GPTK runtime detected. The app runner will be installed with Homebrew if needed."
        }
        if hasLocalD3DMetalRuntime {
            if let app = mountedGPTKAppSource {
                return "Local GPTK runtime exists. GPTK app source detected: \(app)"
            }
            return "Local GPTK runtime exists. The app runner will be installed with Homebrew if needed."
        }
        if let app = mountedGPTKAppSource {
            return "GPTK app source detected: \(app). The GPTK 3.0 runtime is still needed."
        }
        if let dmg = downloadedGPTKDmgPath {
            return "GPTK download detected: \(dmg)"
        }
        return "Waiting for GPTK 3.0 in Downloads, Desktop, or mounted Finder volumes."
    }
    var needsSetupGuide: Bool {
        !exists || !hasToolkitScripts || !hasLocalGPTK
    }

    private var detectedWineHome: String? {
        wineHomeCandidates.first(where: hasWine64Executable)
    }

    private var d3d12Candidates: [String] {
        uniqued(["\(gptkRuntime)/lib/wine/x86_64-windows/d3d12.dll"] + wineHomeCandidates.map {
            "\($0)/lib/wine/x86_64-windows/d3d12.dll"
        })
    }

    private var mountedGPTKAppSource: String? {
        firstDescendant(in: gptkAppSourceRoots, maxDepth: 5) { url in
            url.lastPathComponent == "Game Porting Toolkit.app"
                && FileManager.default.isExecutableFile(atPath: url.appendingPathComponent("Contents/Resources/wine/bin/wine64").path)
        }
    }

    private var mountedGPTKRuntimeSource: String? {
        firstDescendant(in: gptkMediaRoots, maxDepth: 5) { url in
            isGPTKRuntimeRoot(url)
        }
    }

    private var downloadedGPTKDmgPath: String? {
        firstDescendant(in: [gptkDownloadDir, "\(home)/Desktop"], maxDepth: 4) { url in
            let name = url.lastPathComponent.lowercased()
            guard name.hasSuffix(".dmg") else { return false }
            return name.contains("game porting toolkit")
                || (name.contains("game") && name.contains("porting") && name.contains("toolkit"))
                || name.contains("evaluation environment for windows games")
        }
    }

    private var gptkMediaRoots: [String] {
        var roots: [String] = []
        if let source = values["GPTK_SOURCE"]?.strippedShellQuotes, !source.isEmpty {
            roots.append(expand(source))
        }
        if let volumeURLs = try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Volumes", isDirectory: true),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            roots.append(contentsOf: volumeURLs.map(\.path))
        }
        return uniqued(roots)
    }

    private var gptkAppSourceRoots: [String] {
        uniqued(gptkMediaRoots + [
            "/Applications",
            "\(home)/Applications"
        ])
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

    private func isGPTKRuntimeRoot(_ url: URL) -> Bool {
        let directLib = url.appendingPathComponent("lib")
        let redistLib = url.appendingPathComponent("redist/lib")
        return isGPTKRuntimeLibRoot(directLib) || isGPTKRuntimeLibRoot(redistLib)
    }

    private func isGPTKRuntimeLibRoot(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent("wine/x86_64-windows/d3d12.dll").path)
            && FileManager.default.fileExists(atPath: url.appendingPathComponent("external").path)
    }

    private func firstDescendant(
        in roots: [String],
        maxDepth: Int,
        matching predicate: (URL) -> Bool
    ) -> String? {
        let manager = FileManager.default
        for root in roots {
            let rootURL = URL(fileURLWithPath: root)
            guard manager.fileExists(atPath: rootURL.path) else { continue }
            if predicate(rootURL) {
                return rootURL.path
            }
            guard let enumerator = manager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let url as URL in enumerator {
                let depth = url.pathComponents.count - rootURL.pathComponents.count
                if depth > maxDepth {
                    enumerator.skipDescendants()
                    continue
                }
                if predicate(url) {
                    return url.path
                }
            }
        }
        return nil
    }

    private var toolWineHomeCandidates: [String] {
        uniqued([
            "/Applications/Wine Staging.app/Contents/Resources/wine",
            "/Applications/Wine Stable.app/Contents/Resources/wine",
            effectiveWineHome
        ].map(expand))
    }

    private func hasWine64Executable(_ path: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: "\(path)/bin/wine64")
    }

    private func hasWineExecutable(_ path: String) -> Bool {
        hasWine64Executable(path) || FileManager.default.isExecutableFile(atPath: "\(path)/bin/wine")
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
