import AVFoundation
import Combine
import Foundation

enum VoiceDelivery: String, CaseIterable, Codable, Identifiable {
    case focusEnd
    case bedtime
    case nextPresence

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focusEnd: "专注结束后"
        case .bedtime: "今晚睡前"
        case .nextPresence: "下次上线时"
        }
    }

    var detail: String {
        switch self {
        case .focusEnd: "大约 24 分钟"
        case .bedtime: "23:30"
        case .nextPresence: "等待对方出现"
        }
    }
}

struct SavedVoiceNote: Codable, Identifiable, Equatable {
    let id: UUID
    let filename: String
    let duration: TimeInterval
    let createdAt: Date
    let delivery: VoiceDelivery
}

enum VoiceRecorderPhase: Equatable {
    case idle
    case requestingPermission
    case recording
    case recorded
    case playing
    case permissionDenied
    case failed(String)
}

@MainActor
final class VoiceRecorderController: NSObject, ObservableObject {
    @Published private(set) var phase: VoiceRecorderPhase = .idle
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var savedNotes: [SavedVoiceNote] = []

    private let ambientAudio: AmbientAudioControlling
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var draftURL: URL?
    private var tickerTask: Task<Void, Never>?
    private var playingNoteID: SavedVoiceNote.ID?

    init(ambientAudio: AmbientAudioControlling) {
        self.ambientAudio = ambientAudio
        super.init()
        savedNotes = loadSavedNotes()
    }

    deinit {
        tickerTask?.cancel()
        recorder?.stop()
        player?.stop()
    }

    var hasDraft: Bool { draftURL != nil && elapsed > 0 }
    var isRecording: Bool { phase == .recording }
    var isPlaying: Bool { phase == .playing }
    var elapsedText: String { Self.formatDuration(elapsed) }

    func startRecording() async {
        guard phase != .requestingPermission, phase != .recording else { return }
        stopPlayback()
        phase = .requestingPermission

        let authorized: Bool
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            authorized = true
        case .notDetermined:
            authorized = await AVCaptureDevice.requestAccess(for: .audio)
        default:
            authorized = false
        }

        guard authorized else {
            phase = .permissionDenied
            return
        }

        var candidateURL: URL?
        do {
            try discardDraft()
            let url = try makeDraftURL()
            candidateURL = url
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 96_000,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            guard recorder.prepareToRecord(), recorder.record(forDuration: 60) else {
                throw VoiceRecorderError.couldNotStart
            }

            self.recorder = recorder
            draftURL = url
            candidateURL = nil
            elapsed = 0
            phase = .recording
            ambientAudio.setTemporarilyMuted(true)
            startTicker()
        } catch {
            if let candidateURL {
                try? FileManager.default.removeItem(at: candidateURL)
            }
            ambientAudio.setTemporarilyMuted(false)
            phase = .failed(error.localizedDescription)
        }
    }

    func finishRecording() {
        guard let recorder, phase == .recording else { return }
        let duration = min(60, max(recorder.currentTime, elapsed))
        recorder.delegate = nil
        recorder.stop()
        self.recorder = nil
        finishDraft(duration: duration)
    }

    func toggleDraftPlayback() {
        if phase == .playing {
            stopPlayback()
            return
        }
        guard let draftURL else { return }
        play(url: draftURL, noteID: nil, returnPhase: .recorded)
    }

    func togglePlayback(_ note: SavedVoiceNote) {
        if phase == .playing, playingNoteID == note.id {
            stopPlayback()
            return
        }
        play(url: recordingsDirectory.appendingPathComponent(note.filename), noteID: note.id, returnPhase: .idle)
    }

    func isPlaying(_ note: SavedVoiceNote) -> Bool {
        phase == .playing && playingNoteID == note.id
    }

    @discardableResult
    func saveDraft(delivery: VoiceDelivery = .focusEnd) -> SavedVoiceNote? {
        guard let draftURL, hasDraft else { return nil }
        var destination: URL?
        do {
            try FileManager.default.createDirectory(
                at: recordingsDirectory,
                withIntermediateDirectories: true
            )
            let destinationURL = recordingsDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
            destination = destinationURL
            try FileManager.default.moveItem(at: draftURL, to: destinationURL)
            let note = SavedVoiceNote(
                id: UUID(),
                filename: destinationURL.lastPathComponent,
                duration: elapsed,
                createdAt: Date(),
                delivery: delivery
            )
            let updatedNotes = [note] + savedNotes
            try persist(updatedNotes)
            savedNotes = updatedNotes
            self.draftURL = nil
            elapsed = 0
            phase = .idle
            return note
        } catch {
            if
                let destination,
                FileManager.default.fileExists(atPath: destination.path),
                !FileManager.default.fileExists(atPath: draftURL.path)
            {
                try? FileManager.default.moveItem(at: destination, to: draftURL)
            }
            phase = .failed("留声保存失败：\(error.localizedDescription)")
            return nil
        }
    }

    func cancelCurrentRecording() {
        tickerTask?.cancel()
        tickerTask = nil
        recorder?.delegate = nil
        recorder?.stop()
        recorder = nil
        stopPlayback()
        try? discardDraft()
        elapsed = 0
        phase = .idle
        ambientAudio.setTemporarilyMuted(false)
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        playingNoteID = nil
        if draftURL != nil && elapsed > 0 {
            phase = .recorded
        } else if phase == .playing {
            phase = .idle
        }
    }

    /// Stops any in-flight recording/playback and clears saved notes in memory.
    /// On-disk recordings are removed by the app-wide data reset.
    func resetAll() {
        cancelCurrentRecording()
        savedNotes = []
    }

    private var applicationDirectory: URL {
        AppStoragePaths.applicationSupportRoot()
    }

    private var recordingsDirectory: URL {
        AppStoragePaths.recordingsDirectory()
    }

    private var metadataURL: URL {
        AppStoragePaths.voiceNotesURL()
    }

    private func makeDraftURL() throws -> URL {
        try FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
        return recordingsDirectory.appendingPathComponent(".draft-\(UUID().uuidString).m4a")
    }

    private func discardDraft() throws {
        guard let draftURL else { return }
        if FileManager.default.fileExists(atPath: draftURL.path) {
            try FileManager.default.removeItem(at: draftURL)
        }
        self.draftURL = nil
    }

    private func finishDraft(duration: TimeInterval) {
        tickerTask?.cancel()
        tickerTask = nil
        ambientAudio.setTemporarilyMuted(false)
        elapsed = min(60, max(0, duration))
        phase = elapsed > 0 ? .recorded : .failed("没有录到声音，请再试一次。")
    }

    private func startTicker() {
        tickerTask?.cancel()
        tickerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, let recorder = self.recorder, self.phase == .recording else { return }
                self.elapsed = min(60, recorder.currentTime)
            }
        }
    }

    private func play(url: URL, noteID: SavedVoiceNote.ID?, returnPhase: VoiceRecorderPhase) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            guard player.prepareToPlay(), player.play() else {
                throw VoiceRecorderError.couldNotPlay
            }
            self.player = player
            playingNoteID = noteID
            phase = .playing
            playbackReturnPhase = returnPhase
        } catch {
            phase = .failed("留声播放失败：\(error.localizedDescription)")
        }
    }

    private var playbackReturnPhase: VoiceRecorderPhase = .idle

    private func loadSavedNotes() -> [SavedVoiceNote] {
        guard
            let data = try? Data(contentsOf: metadataURL),
            let notes = try? JSONDecoder().decode([SavedVoiceNote].self, from: data)
        else { return [] }
        return notes.filter {
            FileManager.default.fileExists(atPath: recordingsDirectory.appendingPathComponent($0.filename).path)
        }
    }

    private func persist(_ notes: [SavedVoiceNote]) throws {
        try FileManager.default.createDirectory(at: applicationDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(notes)
        try data.write(to: metadataURL, options: .atomic)
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration.rounded(.down)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

extension VoiceRecorderController: AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let duration = recorder.currentTime
        Task { @MainActor [weak self] in
            guard let self, self.recorder === recorder else { return }
            self.recorder = nil
            if flag {
                self.finishDraft(duration: max(duration, self.elapsed))
            } else {
                self.ambientAudio.setTemporarilyMuted(false)
                self.phase = .failed("录音意外中断，请再试一次。")
            }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, self.player === player else { return }
            self.player = nil
            self.playingNoteID = nil
            self.phase = flag ? self.playbackReturnPhase : .failed("留声播放被中断。")
        }
    }
}

private enum VoiceRecorderError: LocalizedError {
    case couldNotStart
    case couldNotPlay

    var errorDescription: String? {
        switch self {
        case .couldNotStart: "无法启动麦克风。"
        case .couldNotPlay: "无法播放这段留声。"
        }
    }
}
