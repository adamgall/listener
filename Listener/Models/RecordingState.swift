import Foundation
import Combine

class RecordingState: ObservableObject {
    @Published var isRecording = false
    @Published var currentTranscript = ""
    @Published var recordingDuration: TimeInterval = 0

    private var timer: Timer?
    private var startTime: Date?

    func startRecording() {
        isRecording = true
        currentTranscript = ""
        startTime = Date()
        recordingDuration = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            self.recordingDuration = Date().timeIntervalSince(startTime)
        }
    }

    func stopRecording() {
        isRecording = false
        timer?.invalidate()
        timer = nil
    }

    func setTranscript(_ text: String, speaker: Speaker) {
        // For live display, just show the text without speaker prefix
        // Speaker labeling will be done at save time using diarization
        currentTranscript = text
    }
}

enum Speaker: Hashable, CustomStringConvertible {
    case you
    case speaker(Int)

    var description: String {
        switch self {
        case .you:
            return "You"
        case .speaker(let id):
            return "Speaker \(id)"
        }
    }
}
