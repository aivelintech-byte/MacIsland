import AppKit
import SwiftUI

// MARK: - Anthropic Logo
// Approximates the official Anthropic geometric mark

private struct AnthropicMark: View {
    var size: CGFloat = 16
    var color: Color = .white

    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            // Outer shape — tall rounded rect
            let outer = Path(roundedRect: CGRect(x: 0, y: 0, width: w, height: h), cornerRadius: w * 0.18)
            ctx.fill(outer, with: .color(color))

            // Inner cutout — inverted triangle cutout at bottom center
            var cut = Path()
            cut.move(to:    CGPoint(x: w * 0.30, y: h * 0.55))
            cut.addLine(to: CGPoint(x: w * 0.70, y: h * 0.55))
            cut.addLine(to: CGPoint(x: w * 0.50, y: h * 0.82))
            cut.closeSubpath()
            ctx.blendMode = .destinationOut
            ctx.fill(cut, with: .color(.black))
        }
        .compositingGroup()
        .frame(width: size, height: size * 1.2)
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
    Shortcut(label: "Claude",   symbol: "sparkles",         action: .url("https://claude.ai")),
    Shortcut(label: "ChatGPT",  symbol: "bubble.left.fill", action: .url("https://chatgpt.com")),
    Shortcut(label: "Spotify",  symbol: "music.note",       action: .url("spotify:")),
    Shortcut(label: "Mac Mini", symbol: "terminal.fill",    action: .ssh(host: "Macmini.fritz.box", user: "macmini")),
]

// MARK: - IslandView

struct IslandView: View {
    @State private var expanded = false
    @StateObject private var monitor = NowPlayingMonitor()
    @StateObject private var session = SessionTracker()
    @StateObject private var weekly  = WeeklyTracker()
    @StateObject private var claude  = ClaudeUsageMonitor()

    private var tokenPercent: Int {
        claude.available ? claude.usage.percentRemaining : session.tokenPercent
    }

    private var pillWidth: CGFloat  { expanded ? 400 : 12 }
    private var pillHeight: CGFloat { expanded ? 76  : 12 }

    var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                Group {
                    if expanded {
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: 22,
                            bottomTrailingRadius: 22,
                            topTrailingRadius: 0
                        )
                        .fill(Color.black)
                        .overlay(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 22,
                                bottomTrailingRadius: 22,
                                topTrailingRadius: 0
                            )
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                        )
                    } else {
                        Circle()
                            .fill(Color.black)
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                    }
                }
                .frame(width: pillWidth, height: pillHeight)
                .shadow(color: .black.opacity(0.7), radius: expanded ? 12 : 4, y: expanded ? 5 : 2)

                if expanded { expandedContent }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: expanded)
            .onHover { expanded = $0 }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear  { monitor.start(); session.start(); claude.start() }
        .onDisappear { monitor.stop(); session.stop(); claude.stop() }
        .onChange(of: session.elapsed) { weekly.update(elapsed: $0) }
    }

    // MARK: - Collapsed

    private var collapsedContent: some View {
        HStack(spacing: 0) {

            // LEFT — session time + bar
            HStack(spacing: 5) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(session.formattedRemaining)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("\(tokenPercent)%")
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
                sessionBar
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            // CENTER — Anthropic mark
            AnthropicMark(size: 13, color: .white)
                .padding(.horizontal, 12)

            // RIGHT — weekly
            VStack(alignment: .leading, spacing: 1) {
                Text("week")
                    .font(.system(size: 8, weight: .regular))
                    .foregroundStyle(.white.opacity(0.4))
                Text(weekly.formatted)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .frame(width: pillWidth, height: pillHeight)
    }

    private var sessionBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.1))
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(session.remaining < 3600 ? 0.5 : 0.85))
                    .frame(height: geo.size.height * (1 - session.progress))
            }
        }
        .frame(width: 2, height: 18)
    }

    // MARK: - Expanded

    private var expandedContent: some View {
        VStack(spacing: 0) {
            if let track = monitor.track { musicRow(track) } else { launcherRow }
            Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 14)
            infoRow
        }
        .frame(width: pillWidth, height: pillHeight)
    }

    private var launcherRow: some View {
        HStack(spacing: 20) {
            ForEach(shortcuts, id: \.label) { s in
                Button { s.execute() } label: {
                    VStack(spacing: 3) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 28, height: 28)
                            Image(systemName: s.symbol)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        Text(s.label)
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
    }

    private func musicRow(_ track: TrackInfo) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 34, height: 34)
                Image(systemName: track.source == .spotify ? "music.note" : "play.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(track.title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                Text(track.artist).font(.system(size: 9)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if track.source == .spotify { spotifyControls }
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
    }

    private var infoRow: some View {
        HStack {
            AnthropicMark(size: 10, color: .white.opacity(0.6))
            Text("Claude")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            Text("·")
                .foregroundStyle(.white.opacity(0.3))
            Text(session.formattedRemaining)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
            Text("·")
                .foregroundStyle(.white.opacity(0.3))
            Text("\(tokenPercent)% tokens")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text(weekly.formatted)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 12)
        .frame(height: 24)
    }

    // MARK: - Music controls

    private var spotifyControls: some View {
        HStack(spacing: 1) {
            controlButton(icon: "backward.fill")  { monitor.previousTrack() }
            controlButton(icon: "playpause.fill") { monitor.togglePlayPause() }
            controlButton(icon: "forward.fill")   { monitor.nextTrack() }
        }
    }

    private func controlButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
