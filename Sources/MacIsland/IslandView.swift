import AppKit
import SwiftUI

// MARK: - Anthropic Logo Shape

private struct AnthropicLogo: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        // Stylised "A" — two outer legs + inner cutout
        p.move(to:    CGPoint(x: w * 0.50, y: 0))
        p.addLine(to: CGPoint(x: w * 1.00, y: h))
        p.addLine(to: CGPoint(x: w * 0.68, y: h))
        p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.40))
        p.addLine(to: CGPoint(x: w * 0.32, y: h))
        p.addLine(to: CGPoint(x: w * 0.00, y: h))
        p.closeSubpath()
        return p
    }
}

// MARK: - Shortcuts

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
        case .url(let s): NSWorkspace.shared.open(URL(string: s)!)
        case .ssh(let host, let user):
            let script = "tell application \"Terminal\" to activate\ntell application \"Terminal\" to do script \"ssh \(user)@\(host)\""
            NSAppleScript(source: script)?.executeAndReturnError(nil)
        }
    }
}

private let shortcuts: [Shortcut] = [
    Shortcut(label: "Claude",   symbol: "sparkles",         color: Color(red: 0.80, green: 0.50, blue: 1.00), action: .url("https://claude.ai")),
    Shortcut(label: "ChatGPT",  symbol: "bubble.left.fill", color: Color(red: 0.20, green: 0.78, blue: 0.58), action: .url("https://chatgpt.com")),
    Shortcut(label: "Spotify",  symbol: "music.note",       color: Color(red: 0.11, green: 0.73, blue: 0.33), action: .url("spotify:")),
    Shortcut(label: "Mac Mini", symbol: "terminal.fill",    color: Color(red: 0.25, green: 0.25, blue: 0.25), action: .ssh(host: "Macmini.fritz.box", user: "macmini")),
]

// MARK: - IslandView

struct IslandView: View {
    @State private var expanded = false
    @StateObject private var monitor = NowPlayingMonitor()
    @StateObject private var session = SessionTracker()
    @StateObject private var weekly  = WeeklyTracker()

    private var pillWidth: CGFloat  { expanded ? 440 : 340 }
    private var pillHeight: CGFloat { expanded ? 90  : 34  }

    var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: expanded ? 26 : 20,
                    bottomTrailingRadius: expanded ? 26 : 20,
                    topTrailingRadius: 0
                )
                .fill(Color.black)
                .frame(width: pillWidth, height: pillHeight)
                .shadow(color: .black.opacity(0.6), radius: 14, y: 6)

                if expanded { expandedContent } else { collapsedContent }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: expanded)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: monitor.track?.title)
            .onHover { expanded = $0 }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear  { monitor.start(); session.start() }
        .onDisappear { monitor.stop(); session.stop() }
        .onChange(of: session.elapsed) { weekly.update(elapsed: $0) }
    }

    // MARK: - Collapsed: [session | %] · [logo] · [weekly]

    private var collapsedContent: some View {
        HStack(spacing: 0) {
            // LEFT — session + token %
            HStack(spacing: 5) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(session.formattedRemaining)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(session.remaining < 3600 ? .orange : .white)
                    Text("\(session.tokenPercent)% tokens")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                tokenBar
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            // CENTER — Anthropic logo
            AnthropicLogo()
                .fill(Color(red: 0.90, green: 0.55, blue: 0.30))
                .frame(width: 18, height: 16)
                .padding(.horizontal, 14)

            // RIGHT — weekly stats
            HStack(spacing: 5) {
                tokenBar.scaleEffect(x: -1)  // mirrored for visual balance
                VStack(alignment: .leading, spacing: 1) {
                    Text("This week")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(weekly.formatted)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .frame(width: pillWidth, height: pillHeight)
    }

    private var tokenBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white.opacity(0.12))
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(sessionBarColor)
                    .frame(height: geo.size.height * (1 - session.progress))
            }
        }
        .frame(width: 3, height: 20)
    }

    private var sessionBarColor: Color {
        switch session.progress {
        case 0..<0.5: return Color(red: 0.80, green: 0.50, blue: 1.00)
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }

    // MARK: - Expanded

    private var expandedContent: some View {
        VStack(spacing: 0) {
            if let track = monitor.track { musicRow(track) } else { launcherRow }
            Divider().background(Color.white.opacity(0.1)).padding(.horizontal, 16)
            claudeRow
        }
        .frame(width: pillWidth, height: pillHeight)
    }

    private var launcherRow: some View {
        HStack(spacing: 16) {
            ForEach(shortcuts, id: \.label) { s in
                Button { s.execute() } label: {
                    VStack(spacing: 3) {
                        ZStack {
                            Circle().fill(s.color).frame(width: 30, height: 30)
                            Image(systemName: s.symbol)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        Text(s.label)
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

    private func musicRow(_ track: TrackInfo) -> some View {
        HStack(spacing: 10) {
            sourceIcon(track)
            VStack(alignment: .leading, spacing: 1) {
                Text(track.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                Text(track.artist).font(.system(size: 10)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if track.source == .spotify { spotifyControls }
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
    }

    private var claudeRow: some View {
        HStack {
            AnthropicLogo()
                .fill(Color(red: 0.90, green: 0.55, blue: 0.30))
                .frame(width: 14, height: 12)
            Text("Claude · \(session.tokenPercent)% left · \(session.formattedRemaining)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(weekly.formatted)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .frame(height: 34)
    }

    // MARK: - Music helpers

    private func sourceIcon(_ track: TrackInfo) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(track.source == .spotify ? Color(red: 0.11, green: 0.73, blue: 0.33) : .red)
                .frame(width: 40, height: 40)
            Image(systemName: track.source == .spotify ? "music.note" : "play.fill")
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
        }
    }

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
