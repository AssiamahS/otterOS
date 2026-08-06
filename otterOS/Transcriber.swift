import Foundation
import AVFoundation
import Speech

/// Live mic capture + on-device transcription via iOS 26 SpeechAnalyzer.
/// Writes the audio to an m4a alongside the rolling transcript.
@MainActor
final class Transcriber: ObservableObject {
    @Published var finalizedText = ""
    @Published var volatileText = ""
    @Published var isRecording = false
    @Published var elapsed: TimeInterval = 0
    @Published var errorMessage: String?

    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var timer: Timer?
    private(set) var currentFileURL: URL?

    var transcript: String {
        (finalizedText + " " + volatileText).trimmingCharacters(in: .whitespaces)
    }

    func start() async {
        guard !isRecording else { return }
        finalizedText = ""; volatileText = ""; elapsed = 0; errorMessage = nil

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            errorMessage = "Audio session: \(error.localizedDescription)"
            return
        }

        guard await AVAudioApplication.requestRecordPermission() else {
            errorMessage = "Microphone permission denied."
            return
        }

        // Locale must come from supportedLocales (BCP-47), not a raw identifier.
        let locale = await SpeechTranscriber.supportedLocales.first {
            $0.identifier(.bcp47) == Locale.current.identifier(.bcp47)
        } ?? Locale(identifier: "en-US")

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        self.transcriber = transcriber

        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
        } catch {
            errorMessage = "Speech model: \(error.localizedDescription)"
            return
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer

        guard let analysisFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            errorMessage = "No compatible audio format for transcription."
            return
        }

        let (inputSequence, builder) = AsyncStream<AnalyzerInput>.makeStream()
        inputBuilder = builder

        let inputFormat = engine.inputNode.outputFormat(forBus: 0)
        let converter = AVAudioConverter(from: inputFormat, to: analysisFormat)

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("rec-\(Int(Date().timeIntervalSince1970)).m4a")
        currentFileURL = url
        audioFile = try? AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: inputFormat.sampleRate,
            AVNumberOfChannelsKey: 1,
        ])

        engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            try? self.audioFile?.write(from: buffer)
            guard let converter else { return }
            let ratio = analysisFormat.sampleRate / inputFormat.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
            guard let converted = AVAudioPCMBuffer(pcmFormat: analysisFormat, frameCapacity: capacity) else { return }
            var fed = false
            var convError: NSError?
            converter.convert(to: converted, error: &convError) { _, outStatus in
                if fed {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                fed = true
                outStatus.pointee = .haveData
                return buffer
            }
            if convError == nil, converted.frameLength > 0 {
                builder.yield(AnalyzerInput(buffer: converted))
            }
        }

        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    await MainActor.run {
                        guard let self else { return }
                        if result.isFinal {
                            self.finalizedText += (self.finalizedText.isEmpty ? "" : " ") + text
                            self.volatileText = ""
                        } else {
                            self.volatileText = text
                        }
                    }
                }
            } catch {
                await MainActor.run { self?.errorMessage = "Transcription: \(error.localizedDescription)" }
            }
        }

        do {
            try engine.start()
            try await analyzer.start(inputSequence: inputSequence)
        } catch {
            errorMessage = "Start failed: \(error.localizedDescription)"
            engine.inputNode.removeTap(onBus: 0)
            return
        }

        isRecording = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.elapsed += 1 }
        }
    }

    func stop() async {
        guard isRecording else { return }
        isRecording = false
        timer?.invalidate(); timer = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        inputBuilder?.finish()
        // Without this, the volatile tail never finalizes and text is lost.
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        resultsTask?.cancel()
        audioFile = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
