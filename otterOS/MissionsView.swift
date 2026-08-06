import SwiftUI

struct MissionsView: View {
    @EnvironmentObject var missions: MissionStore
    @AppStorage("showSteps") private var showSteps = true
    @AppStorage("userName") private var userName = "friend"
    @State private var newTitle = ""
    @State private var newDue: Date = .now.addingTimeInterval(3600)
    @State private var hasDue = false
    @State private var echoBackup = false
    @State private var showAdd = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base = hour < 12 ? "Morning" : hour < 17 ? "Afternoon" : "Evening"
        return "\(base), \(userName)."
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(greeting).font(.title2.bold())
                        if let pick = missions.openMissions.first {
                            Text("Let's knock out “\(pick.title)” — I want this one gone.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("List is CLEAR. That's a sunrise-worthy day.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
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

                Section("Missions") {
                    ForEach(missions.openMissions) { mission in
                        MissionRow(mission: mission)
                    }
                    .onDelete { missions.remove(at: $0, in: missions.openMissions) }
                }

                let done = missions.missions.filter(\.done)
                if !done.isEmpty {
                    Section("Crossed off") {
                        ForEach(done) { mission in
                            MissionRow(mission: mission)
                        }
                        .onDelete { missions.remove(at: $0, in: done) }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("otterOS")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus.circle.fill") }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Toggle("Show steps", isOn: $showSteps)
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(isPresented: $showAdd) { addSheet }
        }
    }

    private var addSheet: some View {
        NavigationStack {
            Form {
                TextField("What needs doing?", text: $newTitle)
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
                        missions.add(newTitle, due: hasDue ? newDue : nil, echoBackup: hasDue && echoBackup)
                        newTitle = ""; hasDue = false; echoBackup = false
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
                    if mission.echoBackup {
                        Label("Echo", systemImage: "homepod.2.fill")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if mission.source == "recording" {
                        Label("from recording", systemImage: "waveform")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
    }
}
