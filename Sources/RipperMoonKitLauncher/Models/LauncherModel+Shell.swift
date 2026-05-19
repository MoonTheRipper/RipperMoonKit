import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension LauncherModel {
    func runShell(
        title: String,
        command: String,
        detached: Bool = false,
        completion: (() -> Void)? = nil,
        successCompletion: (() -> Void)? = nil
    ) {
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
            if result.error == nil && result.status == 0 {
                successCompletion?()
            }
        }
    }
}
