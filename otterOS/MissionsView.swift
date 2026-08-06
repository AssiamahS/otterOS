import SwiftUI

struct MissionsView: View {
    @EnvironmentObject var missions: MissionStore
    @EnvironmentObject var health: HealthManager
    @AppStorage("showSteps") private var showSteps = true
    @AppStorage("userName") private var userName = "friend"
    @State private var quickTitle = ""
    @State private var newTitle = ""
    @State private var newDue: Date = .now.addingTimeInterval(3600)
    @State private var hasDue = false
    @State private var echoBackup = false
    @State private var recurChoice = "never"
    @State private var showAdd = false
    @FocusState private var quickAddFocused: Bool

    private var carriedCount: Int {
        missions.openMissions.filter(\.carriedOver).count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    header
                    quickAdd
                    missionSections
                }
                .listStyle(.plain)

                ConfettiView(trigger: $missions.celebrate)
            }
            .navigationTitle("otterOS")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus.circle.fill") }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Toggle("Show steps", isOn: $showSteps)
                        NavigationLink("Otto's week") { WeeklyReviewView() }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(isPresented: $showAdd) { addSheet }
            .onChange(of: health.steps) { _, steps in
                if steps >= 10_000 { missions.completeStepMissions() }
            }
        }
    }

    private var header: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(OttoPersonality.greeting(
                        name: userName,
                        hour: Calendar.current.component(.hour, from: Date())))
                        .font(.title2.bold())
                    Spacer()
                    if let streak = OttoPersonality.streakLine(missions.streak) {
                        Text(streak)
                            .font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.orange.opacity(0.15), in: Capsule())
                    }
                }
                Text(OttoPersonality.pitch(
                    openCount: missions.openMissions.count,
                    firstTitle: missions.openMissions.first?.title,
                    doneToday: missions.doneToday,
                    streak: missions.streak))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let carried = OttoPersonality.carriedLine(carriedCount) {
                    Text(carried).font(.caption).foregroundStyle(.secondary)
                }
                if missions.doneToday > 0 {
                    Text("\(missions.doneToday) crossed off today")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
            }
            .listRowSeparator(.hidden)

            if showSteps {
                StepsRing()
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
            }
        }
    }

    /// Sub-10-second capture: type, return, done. No sheet, no decisions.
    private var quickAdd: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .foregroundStyle(.orange)
                TextField("Quick mission — type and hit return", text: $quickTitle)
                    .focused($quickAddFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        let title = quickTitle.trimmingCharacters(in: .whitespaces)
                        guard !title.isEmpty else { return }
                        missions.add(title)
                        quickTitle = ""
                        quickAddFocused = true // keep the flow going
                    }
            }
            .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder
    private var missionSections: some View {
        Section("Missions") {
            ForEach(missions.openMissions) { mission in
                MissionRow(mission: mission)
            }
            .onDelete { missions.remove(at: $0, in: missions.openMissions) }
        }

        let doneToday = missions.missions.filter {
            $0.done && Calendar.current.isDateInToday($0.doneDate ?? .distantPast)
        }
        if !doneToday.isEmpty {
            Section("Crossed off today") {
                ForEach(doneToday) { mission in
                    MissionRow(mission: mission)
                }
                .onDelete { missions.remove(at: $0, in: doneToday) }
            }
        }
    }

    private var addSheet: some View {
        NavigationStack {
            Form {
                TextField("What needs doing?", text: $newTitle)
                Picker("Repeats", selection: $recurChoice) {
                    Text("Never").tag("never")
                    Text("Every day").tag("daily")
                    Text("Weekdays").tag("weekdays")
                }
                Toggle("Remind me at a time", isOn: $hasDue)
                if hasDue {
                    DatePicker("When", selection: $newDue)
                    Toggle(isOn: $echoBackup) {
                        Label("Echo backup alarm", systemImage: "homepod.2.fill")
                    }
                    Text("Echo fires even if the phone, watch, and Mac are all dead.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New mission")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        missions.add(newTitle,
                                     due: hasDue ? newDue : nil,
                                     echoBackup: hasDue && echoBackup,
                                     recur: recurChoice == "never" ? nil : recurChoice)
                        newTitle = ""; hasDue = false; echoBackup = false; recurChoice = "never"
                        showAdd = false
                    }
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAdd = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct MissionRow: View {
    @EnvironmentObject var missions: MissionStore
    let mission: Mission

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(duration: 0.35)) { missions.toggle(mission) }
            } label: {
                Image(systemName: mission.done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(mission.done ? .orange : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(mission.title)
                    .strikethrough(mission.done, color: .orange)
                    .foregroundStyle(mission.done ? .secondary : .primary)
                HStack(spacing: 8) {
                    if let due = mission.due {
                        Label(due.formatted(date: .abbreviated, time: .shortened), systemImage: "bell")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if mission.carriedOver && !mission.done {
                        Label("carried over", systemImage: "arrow.uturn.forward")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if mission.recur != nil {
                        Label(mission.recur == "daily" ? "daily" : "weekdays", systemImage: "repeat")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if mission.echoBackup {
                        Label("Echo", systemImage: "homepod.2.fill")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if mission.source == "recording" {
                        Label("from recording", systemImage: "waveform")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if mission.source == "siri" {
                        Label("via Siri", systemImage: "mic.badge.plus")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
    }
}
