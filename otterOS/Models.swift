import Foundation
import SwiftUI
import UIKit
import UserNotifications

struct Mission: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var notes: String = ""
    var done = false
    var created = Date()
    var doneDate: Date?
    var due: Date?
    var echoBackup = false
    var source: String = "manual" // manual | recording
}

@MainActor
final class MissionStore: ObservableObject {
    @Published var missions: [Mission] = [] {
        didSet { save() }
    }

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("missions.json")
    }

    init() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Mission].self, from: data) {
            missions = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(missions) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func seedIfEmpty() {
        guard missions.isEmpty else { return }
        missions = [
            Mission(title: "Call NJ DMV — confirm whether the VA conviction hit my record"),
            Mission(title: "Get 10,000 steps"),
            Mission(title: "Add tomorrow's three missions before bed"),
        ]
    }

    var openMissions: [Mission] { missions.filter { !$0.done } }
    var doneToday: Int {
        missions.filter { $0.done && Calendar.current.isDateInToday($0.doneDate ?? .distantPast) }.count
    }

    func add(_ title: String, notes: String = "", due: Date? = nil, echoBackup: Bool = false, source: String = "manual") {
        var m = Mission(title: title, notes: notes, source: source)
        m.due = due
        m.echoBackup = echoBackup
        missions.insert(m, at: 0)
        if let due {
            NotificationScheduler.schedule(missionId: m.id, title: title, at: due)
            if echoBackup {
                Task { await AlexaBridge.setAlarm(label: title, at: due) }
            }
        }
    }

    func toggle(_ mission: Mission) {
        guard let idx = missions.firstIndex(of: mission) else { return }
        missions[idx].done.toggle()
        missions[idx].doneDate = missions[idx].done ? Date() : nil
        if missions[idx].done {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    func remove(at offsets: IndexSet, in list: [Mission]) {
        let ids = offsets.map { list[$0].id }
        missions.removeAll { ids.contains($0.id) }
    }
}

enum NotificationScheduler {
    static func schedule(missionId: UUID, title: String, at date: Date) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Otto: time to knock this out"
            content.body = title
            content.sound = .default
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: missionId.uuidString, content: content, trigger: trigger))
        }
    }
}

/// Talks to the alexa api.js bridge on the Mac (Tailscale) so a mission's
/// reminder also lands on the Echo Show — the alarm that still fires when
/// every Apple device is dead.
enum AlexaBridge {
    static let base = "http://saints-macbook-air.tail40af16.ts.net:8798"

    static func setAlarm(label: String, at date: Date) async {
        guard let url = URL(string: "\(base)/alarms") else { return }
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        let dateOnly = DateFormatter()
        dateOnly.dateFormat = "yyyy-MM-dd"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 8
        let body: [String: Any] = [
            "time": df.string(from: date),
            "date": dateOnly.string(from: date),
            "label": label,
            "type": "Reminder",
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: req)
    }
}

/// Turns a transcript into an Otter-style digest: overview sentences,
/// action items, and key facts (amounts, dates, confirmation numbers).
enum TranscriptDigest {
    static func summarize(_ transcript: String) -> (overview: String, actions: [String], facts: [String]) {
        let sentences = transcript
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 12 }

        let actionMarkers = ["need to", "needs to", "have to", "i will", "i'll", "you should", "make sure",
                             "contact", "call ", "pay ", "send ", "check ", "confirm", "schedule", "follow up", "verify"]
        var actions: [String] = []
        for s in sentences {
            let lower = s.lowercased()
            if actionMarkers.contains(where: { lower.contains($0) }) && actions.count < 6 {
                actions.append(s)
            }
        }

        var facts: [String] = []
        let patterns = [#"\$[\d,]+(\.\d{2})?"#, #"\b\d{1,2}:\d{2}\s?(am|pm|AM|PM)?\b"#, #"\b(confirmation|reference|case)\s*(number|#)?\s*[:#]?\s*\w{4,}\b"#]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let ns = transcript as NSString
                for match in regex.matches(in: transcript, range: NSRange(location: 0, length: ns.length)).prefix(4) {
                    let hit = ns.substring(with: match.range)
                    if !facts.contains(hit) { facts.append(hit) }
                }
            }
        }

        let overview = sentences.prefix(2).joined(separator: ". ")
            + (sentences.count > 4 ? ". " + (sentences.last ?? "") : "")
        return (overview, actions, facts)
    }
}
