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

    func appendTranscript(_ text: String, speaker: Speaker) {
        let entry = "[\(speaker.description)]: \(text)\n"
        DispatchQueue.main.async {
            self.currentTranscript += entry
        }
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
