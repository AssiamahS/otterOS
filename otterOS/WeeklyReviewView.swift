import SwiftUI

/// Otto's week: the journal as a trophy shelf, not a debt ledger.
struct WeeklyReviewView: View {
    @EnvironmentObject var missions: MissionStore
    @EnvironmentObject var recordings: RecordingStore

    private var lastSeven: [DayRecord] { Array(missions.journal.prefix(7)) }
    private var weekTotal: Int { lastSeven.reduce(missions.doneToday) { $0 + $1.completed } }
    private var bestDay: DayRecord? { lastSeven.max { $0.completed < $1.completed } }

    var body: some View {
        List {
            Section {
                HStack(spacing: 20) {
                    stat("\(weekTotal)", "crossed off\nthis week")
                    stat("\(missions.streak)", "day streak")
                    stat("\(missions.bestStreak)", "best ever")
                }
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
            }

            if let best = bestDay, best.completed > 0 {
                Section("Best day") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(prettyDay(best.day)).font(.headline)
                        Text("\(best.completed) missions down\(best.clearedAll ? " — cleared the whole list" : "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("The record") {
                HStack {
                    Text("Today").font(.subheadline.bold())
                    Spacer()
                    Text("\(missions.doneToday) done").foregroundStyle(.orange)
                }
                ForEach(lastSeven) { day in
                    HStack {
                        Text(prettyDay(day.day)).font(.subheadline)
                        Spacer()
                        if day.clearedAll {
                            Image(systemName: "sparkles").foregroundStyle(.orange)
                        }
                        Text("\(day.completed) done")
                            .foregroundStyle(day.completed > 0 ? .primary : .secondary)
                    }
                }
                if lastSeven.isEmpty {
                    Text("Day one. The record starts tonight.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !recordings.recordings.isEmpty {
                Section {
                    Label("\(recordings.recordings.count) recordings in the library",
                          systemImage: "waveform")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Otto's week")
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack {
            Text(value).font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)
            Text(label).font(.caption2).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func prettyDay(_ day: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: day) else { return day }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}
