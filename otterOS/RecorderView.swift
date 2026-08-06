import SwiftUI

struct RecorderView: View {
    @EnvironmentObject var missions: MissionStore
    @EnvironmentObject var recordings: RecordingStore
    @StateObject private var transcriber = Transcriber()
    @State private var reviewDraft: RecordingDraft?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if transcriber.isRecording {
                    // Guideline 2.5.14: recording must be clearly indicated.
                    Label("REC \(timeString)", systemImage: "record.circle")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(.red)
                        .symbolEffect(.pulse)
                }

                ScrollView {
                    Text(displayTranscript)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .background(.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                if let err = transcriber.errorMessage {
                    Text(err).font(.caption).foregroundStyle(.red)
                }

                Button {
                    Task {
                        if transcriber.isRecording {
                            await transcriber.stop()
                            makeDraft()
                        } else {
                            await transcriber.start()
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(transcriber.isRecording ? Color.red : Color.orange)
                            .frame(width: 84, height: 84)
                        Image(systemName: transcriber.isRecording ? "stop.fill" : "mic.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                }

                Text("Everything stays on this phone. For phone calls: speakerphone, and make sure everyone's cool with it (VA & NJ: one-party consent).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 8)
            }
            .navigationTitle("Record")
            .sheet(item: $reviewDraft) { draft in
                DraftReviewView(draft: draft)
            }
        }
    }

    private var displayTranscript: String {
        let t = transcriber.transcript
        return t.isEmpty ? (transcriber.isRecording ? "Listening…" : "Tap the mic. I'll transcribe, summarize, and pull the to-dos out for you.") : t
    }

    private var timeString: String {
        let s = Int(transcriber.elapsed)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func makeDraft() {
        let transcript = transcriber.transcript
        guard !transcript.isEmpty || transcriber.currentFileURL != nil else { return }
        let digest = TranscriptDigest.summarize(transcript)
        reviewDraft = RecordingDraft(
            transcript: transcript,
            overview: digest.overview,
            actions: digest.actions,
            facts: digest.facts,
            duration: transcriber.elapsed,
            fileName: transcriber.currentFileURL?.lastPathComponent ?? ""
        )
    }
}

struct RecordingDraft: Identifiable {
    let id = UUID()
    var title = ""
    var transcript: String
    var overview: String
    var actions: [String]
    var facts: [String]
    var duration: TimeInterval
    var fileName: String
}

struct DraftReviewView: View {
    @EnvironmentObject var missions: MissionStore
    @EnvironmentObject var recordings: RecordingStore
    @Environment(\.dismiss) private var dismiss
    @State var draft: RecordingDraft
    @State private var keepActions: Set<Int> = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Name this recording", text: $draft.title)
                }
                if !draft.overview.isEmpty {
                    Section("Summary") { Text(draft.overview) }
                }
                if !draft.facts.isEmpty {
                    Section("Key facts") {
                        ForEach(draft.facts, id: \.self) { Text($0) }
                    }
                }
                if !draft.actions.isEmpty {
                    Section("Action items → missions") {
                        ForEach(Array(draft.actions.enumerated()), id: \.offset) { idx, action in
                            Button {
                                if keepActions.contains(idx) { keepActions.remove(idx) } else { keepActions.insert(idx) }
                            } label: {
                                HStack {
                                    Image(systemName: keepActions.contains(idx) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(.orange)
                                    Text(action).foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Otto's digest")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        for idx in keepActions.sorted() {
                            missions.add(draft.actions[idx], source: "recording")
                        }
                        recordings.add(from: draft)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") { dismiss() }
                }
            }
            .onAppear { keepActions = Set(draft.actions.indices) }
        }
    }
}
