import AppIntents

/// "Hey Siri, add a mission in otterOS" — capture without ever opening the app.
struct AddMissionIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Mission"
    static let description = IntentDescription("Give Otto something new to chase.")

    @Parameter(title: "Mission", requestValueDialog: "What needs doing?")
    var missionTitle: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        MissionStore.shared.add(missionTitle, source: "siri")
        return .result(dialog: "On the list. Otto's on it.")
    }
}

/// "Hey Siri, what's on my otterOS list"
struct TodayMissionsIntent: AppIntent {
    static let title: LocalizedStringResource = "Today's Missions"
    static let description = IntentDescription("Hear what's still open today.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let open = MissionStore.shared.missions.filter { !$0.done }
        if open.isEmpty {
            return .result(dialog: "List is clear. Otto is strutting.")
        }
        let titles = open.prefix(5).map(\.title).joined(separator: ", ")
        return .result(dialog: "\(open.count) open: \(titles)")
    }
}

struct OttoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddMissionIntent(),
            phrases: [
                "Add a mission in \(.applicationName)",
                "Tell \(.applicationName) to remember something",
            ],
            shortTitle: "Add Mission",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: TodayMissionsIntent(),
            phrases: [
                "What's on my \(.applicationName) list",
                "Ask \(.applicationName) what's left today",
            ],
            shortTitle: "Today's Missions",
            systemImageName: "sun.max.fill"
        )
    }
}
