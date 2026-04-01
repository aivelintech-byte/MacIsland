import SwiftUI

struct IslandView: View {
    @State private var expanded = false
    @StateObject private var monitor = NowPlayingMonitor()

    private var pillWidth: CGFloat {
        guard monitor.track != nil else { return expanded ? 360 : 120 }
        return expanded ? 360 : 180
    }

    private var pillHeight: CGFloat {
        expanded ? 80 : 34
    }

    var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                RoundedRectangle(cornerRadius: expanded ? 26 : 20)
                    .fill(Color.black)
                    .frame(width: pillWidth, height: pillHeight)
                    .shadow(color: .black.opacity(0.5), radius: 12, y: 4)

                if expanded {
                    expandedContent
                } else if let track = monitor.track {
                    collapsedTrack(track)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: expanded)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: monitor.track?.title)
            .onHover { expanded = $0 }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 8)
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }

    // MARK: - Collapsed

    @ViewBuilder
    private func collapsedTrack(_ track: TrackInfo) -> some View {
        HStack(spacing: 6) {
            Image(systemName: track.source == .spotify ? "music.note" : "play.rectangle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
            Text(track.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 10)
        .frame(width: pillWidth)
    }

    // MARK: - Expanded

    @ViewBuilder
    private var expandedContent: some View {
        if let track = monitor.track {
            HStack(spacing: 12) {
                sourceIcon(track)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if track.source == .spotify {
                    spotifyControls
                }
            }
            .padding(.horizontal, 14)
            .frame(width: 360)
        } else {
            // idle expanded state
            Text("Nothing playing")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    @ViewBuilder
    private func sourceIcon(_ track: TrackInfo) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(track.source == .spotify
                      ? Color(red: 0.11, green: 0.73, blue: 0.33)
                      : Color(red: 1, green: 0, blue: 0))
                .frame(width: 52, height: 52)
            Image(systemName: track.source == .spotify ? "music.note" : "play.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var spotifyControls: some View {
        HStack(spacing: 4) {
            controlButton(icon: "backward.fill") { monitor.previousTrack() }
            controlButton(icon: "playpause.fill") { monitor.togglePlayPause() }
            controlButton(icon: "forward.fill") { monitor.nextTrack() }
        }
    }

    private func controlButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
