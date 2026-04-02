import Foundation

struct ClaudeUsage {
    let inputTokens: Int
    let outputTokens: Int

    static let contextLimit = 200_000

    var total: Int { inputTokens + outputTokens }
    var percentUsed: Int { min(100, inputTokens * 100 / Self.contextLimit) }
    var percentRemaining: Int { max(0, 100 - percentUsed) }

    var formatted: String {
        let t = inputTokens
        if t >= 1000 { return String(format: "%.1fk ctx", Double(t) / 1000) }
        return "\(t) ctx"
    }
}

final class ClaudeUsageMonitor: ObservableObject {
    @Published var usage: ClaudeUsage = ClaudeUsage(inputTokens: 0, outputTokens: 0)
    @Published var available = false

    private var timer: Timer?

    func start() {
        fetch()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.fetch()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func fetch() {
        DispatchQueue.global(qos: .background).async {
            guard let file = self.latestJSONL() else { return }
            let (inp, out) = self.parseTokens(from: file)
            DispatchQueue.main.async {
                self.available = inp + out > 0
                self.usage = ClaudeUsage(inputTokens: inp, outputTokens: out)
            }
        }
    }

    private func latestJSONL() -> URL? {
        let claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
        guard let projectDirs = try? FileManager.default.contentsOfDirectory(
            at: claudeDir, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return nil }

        var latestFile: URL?
        var latestDate = Date.distantPast
        for dir in projectDirs {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { continue }
            for file in files where file.pathExtension == "jsonl" {
                let date = (try? file.resourceValues(
                    forKeys: [.contentModificationDateKey]
                ))?.contentModificationDate ?? .distantPast
                if date > latestDate { latestDate = date; latestFile = file }
            }
        }
        return latestFile
    }

    private func parseTokens(from file: URL) -> (Int, Int) {
        guard let content = try? String(contentsOf: file) else { return (0, 0) }
        var lastInp = 0
        var totalOut = 0
        for line in content.components(separatedBy: "\n") {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let message = json["message"] as? [String: Any],
                  let u = message["usage"] as? [String: Any]
            else { continue }
            let inp = (u["input_tokens"] as? Int ?? 0) + (u["cache_creation_input_tokens"] as? Int ?? 0)
            if inp > 0 { lastInp = inp }
            totalOut += (u["output_tokens"] as? Int ?? 0)
        }
        return (lastInp, totalOut)
    }
}
