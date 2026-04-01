import AppKit
import Foundation

private struct GitHubRelease: Decodable {
    let tagName: String
    let assets: [Asset]

    struct Asset: Decodable {
        let name: String
        let browserDownloadUrl: String

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadUrl = "browser_download_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }
}

final class AutoUpdater {
    static let currentVersion = "1.0.0"
    private let repo = "aivelintech-byte/MacIsland"

    func checkForUpdates() {
        Task { await performCheck() }
    }

    private func performCheck() async {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("MacIsland/\(AutoUpdater.currentVersion)", forHTTPHeaderField: "User-Agent")

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let release = try? JSONDecoder().decode(GitHubRelease.self, from: data)
        else { return }

        let latest = release.tagName.drop(while: { $0 == "v" }).description
        guard isNewer(latest, than: AutoUpdater.currentVersion) else { return }

        guard let asset = release.assets.first(where: { $0.name == "MacIsland" }),
              let downloadURL = URL(string: asset.browserDownloadUrl)
        else { return }

        await downloadAndReplace(from: downloadURL)
    }

    private func isNewer(_ version: String, than current: String) -> Bool {
        let parts = { (v: String) in v.split(separator: ".").compactMap { Int($0) } }
        for (l, c) in zip(parts(version), parts(current)) {
            if l != c { return l > c }
        }
        return parts(version).count > parts(current).count
    }

    private func downloadAndReplace(from url: URL) async {
        guard let (tmpURL, _) = try? await URLSession.shared.download(from: url) else { return }

        let selfURL = URL(fileURLWithPath: CommandLine.arguments[0])

        do {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tmpURL.path)
            _ = try FileManager.default.replaceItemAt(selfURL, withItemAt: tmpURL)

            let task = Process()
            task.executableURL = selfURL
            try task.run()

            await MainActor.run { NSApplication.shared.terminate(nil) }
        } catch {
            // best-effort — silently skip on failure
        }
    }
}
