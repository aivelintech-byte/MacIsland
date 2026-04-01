import AppKit
import Foundation

struct TrackInfo: Equatable {
    let title: String
    let artist: String
    let source: Source

    enum Source { case spotify, youtube }
}

final class NowPlayingMonitor: ObservableObject {
    @Published var track: TrackInfo?

    private var timer: Timer?

    func start() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Playback control (Spotify only)

    func togglePlayPause() {
        guard track?.source == .spotify else { return }
        run("tell application \"Spotify\" to playpause")
    }

    func nextTrack() {
        guard track?.source == .spotify else { return }
        run("tell application \"Spotify\" to next track")
    }

    func previousTrack() {
        guard track?.source == .spotify else { return }
        run("tell application \"Spotify\" to previous track")
    }

    // MARK: - Private

    private func poll() {
        DispatchQueue.global(qos: .userInitiated).async {
            let info = self.spotifyInfo() ?? self.youtubeChrome() ?? self.youtubeSafari()
            DispatchQueue.main.async { self.track = info }
        }
    }

    private func spotifyInfo() -> TrackInfo? {
        let result = eval("""
        if application "Spotify" is running then
            tell application "Spotify"
                if player state is playing then
                    return (name of current track) & "||" & (artist of current track)
                end if
            end tell
        end if
        return ""
        """)
        return parse(result, source: .spotify)
    }

    private func youtubeChrome() -> TrackInfo? {
        for app in ["Google Chrome", "Chromium", "Brave Browser"] {
            let result = eval("""
            if application "\(app)" is running then
                tell application "\(app)"
                    repeat with w in windows
                        repeat with t in tabs of w
                            if URL of t contains "youtube.com/watch" then
                                set ttl to title of t
                                if ttl ends with " - YouTube" then
                                    return (text 1 thru ((length of ttl) - 9) of ttl) & "||YouTube"
                                end if
                            end if
                        end repeat
                    end repeat
                end tell
            end if
            return ""
            """)
            if let info = parse(result, source: .youtube) { return info }
        }
        return nil
    }

    private func youtubeSafari() -> TrackInfo? {
        let result = eval("""
        if application "Safari" is running then
            tell application "Safari"
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains "youtube.com/watch" then
                            set ttl to name of t
                            if ttl ends with " - YouTube" then
                                return (text 1 thru ((length of ttl) - 9) of ttl) & "||YouTube"
                            end if
                        end if
                    end repeat
                end repeat
            end tell
        end if
        return ""
        """)
        return parse(result, source: .youtube)
    }

    private func eval(_ source: String) -> String? {
        var error: NSDictionary?
        return NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue
    }

    private func run(_ source: String) {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
    }

    private func parse(_ raw: String?, source: TrackInfo.Source) -> TrackInfo? {
        guard let raw, !raw.isEmpty else { return nil }
        let parts = raw.components(separatedBy: "||")
        guard parts.count >= 2 else { return nil }
        let title = parts[0].trimmingCharacters(in: .whitespaces)
        let artist = parts[1].trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return nil }
        return TrackInfo(title: title, artist: artist, source: source)
    }
}
