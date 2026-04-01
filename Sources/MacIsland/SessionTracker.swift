import Foundation

final class SessionTracker: ObservableObject {
    static let sessionDuration: TimeInterval = 5 * 3600  // 5 hours

    @Published var elapsed: TimeInterval = 0

    var remaining: TimeInterval { max(0, Self.sessionDuration - elapsed) }
    var progress: Double { min(1, elapsed / Self.sessionDuration) }

    var formattedRemaining: String {
        let h = Int(remaining) / 3600
        let m = Int(remaining) % 3600 / 60
        let s = Int(remaining) % 60
        if h > 0 { return String(format: "%d:%02d left", h, m) }
        return String(format: "%d:%02d left", m, s)
    }

    var tokenPercent: Int { max(0, Int((1 - progress) * 100)) }

    var formattedElapsed: String {
        let h = Int(elapsed) / 3600
        let m = Int(elapsed) % 3600 / 60
        return h > 0 ? String(format: "%dh %02dm", h, m) : String(format: "%dm", m)
    }

    private var timer: Timer?
    private let startTime = Date()

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.elapsed = Date().timeIntervalSince(self.startTime)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
