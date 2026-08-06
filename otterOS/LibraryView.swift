import SwiftUI
import AVFoundation

struct Recording: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var date = Date()
    var duration: TimeInterval
    var transcript: String
    var overview: String
    var actions: [String]
    var facts: [String]
    var fileName: String
}

@MainActor
final class RecordingStore: ObservableObject {
    @Published var recordings: [Recording] = [] {
        didSet { save() }
    }

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recordings.json")
    }

    init() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Recording].self, from: data) {
            recordings = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(recordings) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func add(from draft: RecordingDraft) {
        let rec = Recording(
            title: draft.title.isEmpty ? "Recording \(recordings.count + 1)" : draft.title,
            duration: draft.duration,
            transcript: draft.transcript,
            overview: draft.overview,
            actions: draft.actions,
            facts: draft.facts,
            fileName: draft.fileName
        )
        recordings.insert(rec, at: 0)
    }

    func remove(at offsets: IndexSet) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for idx in offsets {
            let rec = recordings[idx]
            if !rec.fileName.isEmpty {
                try? FileManager.default.removeItem(at: docs.appendingPathComponent(rec.fileName))
            }
        }
        recordings.remove(atOffsets: offsets)
    }
}

struct LibraryView: View {
    @EnvironmentObject var recordings: RecordingStore

    var body: some View {
        NavigationStack {
            Group {
                if recordings.recordings.isEmpty {
                    ContentUnavailableView(
                        "Nothing recorded yet",
                        systemImage: "waveform",
                        description: Text("Recordings land here with summaries and action items.")
                    )
                } else {
                    List {
                        ForEach(recordings.recordings) { rec in
                            NavigationLink(value: rec.id) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(rec.title).font(.headline)
                                    Text("\(rec.date.formatted(date: .abbreviated, time: .shortened)) · \(Int(rec.duration / 60)) min · \(rec.actions.count) actions")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { recordings.remove(at: $0) }
                    }
                }
            }
            .navigationTitle("Library")
            .navigationDestination(for: UUID.self) { id in
                if let rec = recordings.recordings.first(where: { $0.id == id }) {
                    RecordingDetailView(recording: rec)
                }
            }
        }
    }
}

struct RecordingDetailView: View {
    let recording: Recording
    @State private var player: AVAudioPlayer?
    @State private var playing = false

    var body: some View {
        List {
            if !recording.fileName.isEmpty {
                Button {
                    togglePlayback()
                } label: {
                    Label(playing ? "Pause" : "Play audio", systemImage: playing ? "pause.circle.fill" : "play.circle.fill")
                }
            }
            if !recording.overview.isEmpty {
                Section("Summary") { Text(recording.overview) }
            }
            if !recording.facts.isEmpty {
                Section("Key facts") {
                    ForEach(recording.facts, id: \.self) { Text($0) }
                }
            }
            if !recording.actions.isEmpty {
                Section("Action items") {
                    ForEach(recording.actions, id: \.self) { Text($0) }
                }
            }
            Section("Transcript") {
                Text(recording.transcript.isEmpty ? "(empty)" : recording.transcript)
                    .font(.callout)
            }
        }
        .navigationTitle(recording.title)
        .onDisappear { player?.stop() }
    }

    private func togglePlayback() {
        if playing {
            player?.pause()
            playing = false
            return
        }
        if player == nil {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(recording.fileName)
            player = try? AVAudioPlayer(contentsOf: url)
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        player?.play()
        playing = true
    }
}
