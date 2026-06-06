import Foundation
import SwiftUI

/// UI ile worker arasındaki köprü. İşi arka planda yürütür, durumu ana iş
/// parçacığında yayınlar.
@MainActor
final class LoopEngine: ObservableObject {
    @Published var isRunning = false
    @Published var progress: Double = 0
    @Published var logLines: [String] = []
    @Published var lastError: String?
    @Published var resultURL: URL?

    let tools = FFmpegTools.locate()

    var toolsAvailable: Bool { tools != nil }

    func run(input: URL, output: URL, options: LoopOptions) {
        guard let tools else {
            lastError = FFmpegTools.ToolError.notFound.localizedDescription
            return
        }
        guard !isRunning else { return }

        isRunning = true
        progress = 0
        logLines = []
        lastError = nil
        resultURL = nil

        let inPath = input.path
        let outPath = output.path

        Task.detached(priority: .userInitiated) {
            let looper = Looper(
                tools: tools,
                log: { line in Task { @MainActor in self.append(line) } },
                progress: { p in Task { @MainActor in self.progress = max(self.progress, p) } }
            )
            do {
                _ = try looper.process(input: inPath, output: outPath, options: options)
                await MainActor.run {
                    self.resultURL = output
                    self.isRunning = false
                    self.progress = 1
                }
            } catch {
                await MainActor.run {
                    self.lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    self.append("HATA: \(self.lastError ?? "")")
                    self.isRunning = false
                }
            }
        }
    }

    private func append(_ line: String) {
        logLines.append(line)
        if logLines.count > 500 {
            logLines.removeFirst(logLines.count - 500)
        }
    }
}
