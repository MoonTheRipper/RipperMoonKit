import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum ShellExecutor {
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
                    // Drain the pipe *before* waiting — large output (e.g. `ps -axww`)
                    // overruns the ~64 KB pipe buffer and would otherwise deadlock:
                    // the child blocks on write while waitUntilExit() blocks on the child.
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: ShellResult(status: process.terminationStatus, output: output, error: nil))
                } catch {
                    continuation.resume(returning: ShellResult(status: -1, output: "", error: error.localizedDescription))
                }
            }
        }
    }
}

struct ShellResult: Sendable {
    let status: Int32
    let output: String
    let error: String?
}
