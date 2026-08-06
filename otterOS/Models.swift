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
    var carriedOver = false
    var recur: String? // nil | daily | weekdays
}

/// One sealed day: written at sunrise reset, never edited again.
/// Yesterday becomes a record you can read, not a pile you owe.
struct DayRecord: Codable, Identifiable {
    var id: String { day }
    var day: String            // yyyy-MM-dd
    var completed: Int
    var open: Int
    var clearedAll: Bool
    var completedTitles: [String] = []
}

@MainActor
final class MissionStore: ObservableObject {
    /// Single source of truth shared by the app UI, Siri intents, and
    /// notification actions — all of which may launch the process.
    static let shared = MissionStore()

    @Published var missions: [Mission] = [] {
        didSet { save() }
    }
    @Published var journal: [DayRecord] = [] {
        didSet { saveJournal() }
    }
    @Published var celebrate = false

    @AppStorage("streak") var streak = 0
    @AppStorage("bestStreak") var bestStreak = 0
    @AppStorage("lastResetDay") private var lastResetDay = ""

    private static let dayFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("missions.json")
    }
    private var journalURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("journal.json")
    }

    init() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Mission].self, from: data) {
            missions = decoded
        }
        if let data = try? Data(contentsOf: journalURL),
           let decoded = try? JSONDecoder().decode([DayRecord].self, from: data) {
            journal = decoded
        }
        sunriseResetIfNeeded()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(missions) {
            try? data.write(to: fileURL, options: .atomic)
        }
        refreshBadge()
    }

    private func saveJournal() {
        if let data = try? JSONEncoder().encode(journal) {
            try? data.write(to: journalURL, options: .atomic)
        }
    }

    /// The daily reset: seal everything finished before today into the journal,
    /// mark surviving missions as carried over (a chip, not a red number),
    /// respawn recurring missions, and update the streak.
    func sunriseResetIfNeeded() {
        let today = Self.dayFormat.string(from: Date())
        guard lastResetDay != today else { return }

        let finishedEarlier = missions.filter {
            $0.done && !($0.doneDate.map { Calendar.current.isDateInToday($0) } ?? false)
        }
        let yesterday = Self.dayFormat.string(
            from: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        if !lastResetDay.isEmpty {
            let record = DayRecord(
                day: lastResetDay,
                completed: finishedEarlier.count,
                open: missions.filter { !$0.done }.count,
                clearedAll: !finishedEarlier.isEmpty && missions.allSatisfy(\.done),
                completedTitles: finishedEarlier.map(\.title)
            )
            journal.insert(record, at: 0)
            journal = Array(journal.prefix(90))
            // A streak only survives if the sealed day was literally yesterday —
            // skipping days breaks the chain.
            if record.completed > 0 && record.day == yesterday {
                streak = consecutiveCompletedDays()
                bestStreak = max(bestStreak, streak)
            } else {
                streak = 0
            }
        }

        // Sealed missions leave the list; open ones carry forward guilt-free.
        let recurringTemplates = finishedEarlier.filter { $0.recur != nil }
        missions.removeAll { m in finishedEarlier.contains(where: { $0.id == m.id }) }
        for idx in missions.indices where !missions[idx].done {
            missions[idx].carriedOver = true
            if let due = missions[idx].due, due < Date() {
                missions[idx].due = nil // stale reminder time; the mission stays
            }
        }
        respawnRecurring(recurringTemplates)
        lastResetDay = today
    }

    /// Walk the journal newest-first counting contiguous days with ≥1 completion.
    private func consecutiveCompletedDays() -> Int {
        var count = 0
        var cursor = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!
        for record in journal {
            guard record.day == Self.dayFormat.string(from: cursor), record.completed > 0 else { break }
            count += 1
            cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor)!
        }
        return count
    }

    private func respawnRecurring(_ templates: [Mission]) {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let isWeekday = (2...6).contains(weekday)
        for m in templates {
            let shouldRespawn = m.recur == "daily" || (m.recur == "weekdays" && isWeekday)
            if shouldRespawn, !missions.contains(where: { !$0.done && $0.title == m.title }) {
                var fresh = Mission(title: m.title, source: m.source)
                fresh.recur = m.recur
                missions.insert(fresh, at: 0)
            }
        }
    }

    func refreshBadge() {
        let openCount = missions.filter { !$0.done }.count
        UNUserNotificationCenter.current().setBadgeCount(openCount)
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

    func add(_ title: String, notes: String = "", due: Date? = nil, echoBackup: Bool = false, source: String = "manual", recur: String? = nil) {
        var m = Mission(title: title, notes: notes, source: source)
        m.due = due
        m.echoBackup = echoBackup
        m.recur = recur
        missions.insert(m, at: 0)
        if let due {
            NotificationScheduler.schedule(missionId: m.id, title: title, at: due)
            if echoBackup {
                Task { await AlexaBridge.setAlarm(label: title, at: due) }
            }
        }
    }

    func toggle(_ mission: Mission) {
        guard let idx = missions.firstIndex(where: { $0.id == mission.id }) else { return }
        missions[idx].done.toggle()
        missions[idx].doneDate = missions[idx].done ? Date() : nil
        if missions[idx].done {
            NotificationScheduler.cancel(missionId: mission.id)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if missions.allSatisfy(\.done) {
                celebrate = true
            }
        }
    }

    func complete(id: UUID) {
        guard let m = missions.first(where: { $0.id == id }), !m.done else { return }
        toggle(m)
    }

    /// Auto-cross step-goal missions the moment HealthKit says 10k is done.
    func completeStepMissions() {
        for m in missions where !m.done {
            let lower = m.title.lowercased()
            if lower.contains("10,000 steps") || lower.contains("10000 steps") || lower.contains("10k steps") {
                toggle(m)
            }
        }
    }

    func remove(at offsets: IndexSet, in list: [Mission]) {
        let ids = offsets.map { list[$0].id }
        ids.forEach { NotificationScheduler.cancel(missionId: $0) }
        missions.removeAll { ids.contains($0.id) }
    }
}

enum NotificationScheduler {
    static let categoryId = "MISSION_DUE"
    static let completeAction = "COMPLETE"
    static let snoozeAction = "SNOOZE_15"

    /// Registered once at launch so mission notifications carry
    /// Complete / Snooze buttons.
    static func registerCategories() {
        let complete = UNNotificationAction(identifier: completeAction, title: "✓ Done — cross it off", options: [])
        let snooze = UNNotificationAction(identifier: snoozeAction, title: "Snooze 15 min", options: [])
        let category = UNNotificationCategory(identifier: categoryId, actions: [complete, snooze], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func schedule(missionId: UUID, title: String, at date: Date) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Otto: time to knock this out"
            content.body = title
            content.sound = .default
            content.categoryIdentifier = categoryId
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: missionId.uuidString, content: content, trigger: trigger))
        }
    }

    static func cancel(missionId: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [missionId.uuidString])
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
