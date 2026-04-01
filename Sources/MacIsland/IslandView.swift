import AppKit
import SwiftUI

private enum ShortcutAction {
    case url(String)
    case ssh(host: String, user: String)
}

private struct Shortcut {
    let label: String
    let symbol: String
    let color: Color
    let action: ShortcutAction

    func execute() {
        switch action {
        case .url(let urlString):
            NSWorkspace.shared.open(URL(string: urlString)!)
        case .ssh(let host, let user):
            let script = """
            tell application "Terminal"
                activate
                do script "ssh \(user)@\(host)"
            end tell
            """
            NSAppleScript(source: script)?.executeAndReturnError(nil)
        }
    }
}

private let shortcuts: [Shortcut] = [
    Shortcut(label: "Claude",   symbol: "sparkles",          color: Color(red: 0.80, green: 0.50, blue: 1.00), action: .url("https://claude.ai")),
    Shortcut(label: "ChatGPT",  symbol: "bubble.left.fill",  color: Color(red: 0.20, green: 0.78, blue: 0.58), action: .url("https://chatgpt.com")),
    Shortcut(label: "Spotify",  symbol: "music.note",        color: Color(red: 0.11, green: 0.73, blue: 0.33), action: .url("spotify:")),
    Shortcut(label: "Mac Mini", symbol: "terminal.fill",     color: Color(red: 0.20, green: 0.20, blue: 0.20), action: .ssh(host: "Macmini.fritz.box", user: "macmini")),
]

struct IslandView: View {
    @State private var expanded = false
    @StateObject private var monitor = NowPlayingMonitor()
    @StateObject private var session = SessionTracker()

    private var pillWidth: CGFloat {
        expanded ? 440 : 300
    }

    private var pillHeight: CGFloat { expanded ? 90 : 34 }

    var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                // pill shape — top corners flat (flush with screen edge), bottom rounded
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: expanded ? 26 : 20,
                    bottomTrailingRadius: expanded ? 26 : 20,
                    topTrailingRadius: 0
                )
                .fill(Color.black)
                .frame(width: pillWidth, height: pillHeight)
                .shadow(color: .black.opacity(0.6), radius: 14, y: 6)

                if expanded {
                    expandedContent
                } else {
                    collapsedContent
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: expanded)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: monitor.track?.title)
            .onHover { expanded = $0 }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // no top padding — flush with screen edge
        .onAppear {
            monitor.start()
            session.start()
        }
        .onDisappear {
            monitor.stop()
            session.stop()
        }
    }

    // MARK: - Collapsed

    @ViewBuilder
    private var collapsedContent: some View {
        HStack(spacing: 8) {
            // Claude logo
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(red: 0.80, green: 0.50, blue: 1.00))

            // Music info if playing
            if let track = monitor.track {
                Image(systemName: track.source == .spotify ? "music.note" : "play.rectangle.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Text(track.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 70)
            }

            Spacer(minLength: 4)

            // Session timer + bar always visible
            HStack(spacing: 6) {
                Text(session.formattedRemaining)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(session.remaining < 3600 ? Color.orange : Color.white.opacity(0.85))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.15))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(sessionBarColor)
                            .frame(width: geo.size.width * (1 - session.progress))
                    }
                }
                .frame(width: 50, height: 4)
            }
        }
        .padding(.horizontal, 12)
        .frame(width: pillWidth)
    }

    // MARK: - Expanded

    @ViewBuilder
    private var expandedContent: some View {
        VStack(spacing: 0) {
            // Top row: shortcuts or music
            if let track = monitor.track {
                musicRow(track)
            } else {
                launcherRow
            }

            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.horizontal, 16)

            // Bottom row: Claude info + session timer + token bar
            claudeRow
        }
        .frame(width: pillWidth, height: pillHeight)
    }

    @ViewBuilder
    private var launcherRow: some View {
        HStack(spacing: 14) {
            ForEach(shortcuts, id: \.label) { shortcut in
                Button { shortcut.execute() } label: {
                    VStack(spacing: 3) {
                        ZStack {
                            Circle()
                                .fill(shortcut.color)
                                .frame(width: 30, height: 30)
                            Image(systemName: shortcut.symbol)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        Text(shortcut.label)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
    }

    @ViewBuilder
    private func musicRow(_ track: TrackInfo) -> some View {
        HStack(spacing: 10) {
            sourceIcon(track)
            VStack(alignment: .leading, spacing: 1) {
                Text(track.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if track.source == .spotify { spotifyControls }
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
    }

    @ViewBuilder
    private var claudeRow: some View {
        HStack(spacing: 10) {
            // Claude logo + label
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(red: 0.80, green: 0.50, blue: 1.00))
                Text("Claude")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Spacer()

            // Session progress bar
            VStack(alignment: .trailing, spacing: 2) {
                Text(session.formattedRemaining)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(session.remaining < 3600 ? Color.orange : Color.white.opacity(0.7))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.15))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(sessionBarColor)
                            .frame(width: geo.size.width * (1 - session.progress))
                    }
                }
                .frame(width: 80, height: 4)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 34)
    }

    private var sessionBarColor: Color {
        switch session.progress {
        case 0..<0.5: return Color(red: 0.80, green: 0.50, blue: 1.00)
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }

    // MARK: - Shared

    @ViewBuilder
    private func sourceIcon(_ track: TrackInfo) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(track.source == .spotify
                      ? Color(red: 0.11, green: 0.73, blue: 0.33)
                      : Color(red: 1, green: 0, blue: 0))
                .frame(width: 40, height: 40)
            Image(systemName: track.source == .spotify ? "music.note" : "play.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var spotifyControls: some View {
        HStack(spacing: 2) {
            controlButton(icon: "backward.fill")  { monitor.previousTrack() }
            controlButton(icon: "playpause.fill") { monitor.togglePlayPause() }
            controlButton(icon: "forward.fill")   { monitor.nextTrack() }
        }
    }

    private func controlButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
