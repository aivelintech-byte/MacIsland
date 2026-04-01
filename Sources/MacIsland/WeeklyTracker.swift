import Foundation

private struct SessionRecord: Codable {
    let startDate: Date
    var duration: TimeInterval
}

final class WeeklyTracker: ObservableObject {
    @Published var sessionsThisWeek: Int = 0
    @Published var hoursThisWeek: Double = 0

    private let storageURL: URL
    private var sessions: [SessionRecord] = []
    private let sessionStart = Date()

    init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".macisland")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("sessions.json")
        load()
        sessions.append(SessionRecord(startDate: sessionStart, duration: 0))
        save()
        recalc()
    }

    func update(elapsed: TimeInterval) {
        guard !sessions.isEmpty else { return }
        sessions[sessions.count - 1].duration = elapsed
        recalc()
        save()
    }

    var formatted: String {
        let totalMin = Int(hoursThisWeek * 60)
        let h = totalMin / 60
        let m = totalMin % 60
        let time = h > 0 ? "\(h)h\(m > 0 ? "\(m)m" : "")" : "\(m)m"
        return "\(sessionsThisWeek)× · \(time)"
    }

    private func recalc() {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        let recent = sessions.filter { $0.startDate > cutoff }
        sessionsThisWeek = recent.count
        hoursThisWeek = recent.reduce(0) { $0 + $1.duration } / 3600
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let records = try? JSONDecoder().decode([SessionRecord].self, from: data)
        else { return }
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        sessions = records.filter { $0.startDate > cutoff }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        try? data.write(to: storageURL)
    }
}
