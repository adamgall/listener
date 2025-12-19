import Foundation
import Speech
import AVFoundation

class SpeechTranscriber {
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    var onTranscription: ((String, Bool) -> Void)? // (text, isFinal)

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startTranscribing() throws {
        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw TranscriptionError.modelNotLoaded
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw TranscriptionError.transcriptionFailed("Could not create recognition request")
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result = result {
                let text = result.bestTranscription.formattedString
                let isFinal = result.isFinal
                self?.onTranscription?(text, isFinal)
            }

            if error != nil || result?.isFinal == true {
                self?.recognitionRequest = nil
                self?.recognitionTask = nil
            }
        }
    }

    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }

    func stopTranscribing() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }
}
