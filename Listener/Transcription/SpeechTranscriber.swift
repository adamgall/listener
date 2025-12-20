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

    private var appendCount = 0

    func startTranscribing() throws {
        guard let recognizer = recognizer, recognizer.isAvailable else {
            print("DEBUG: SpeechTranscriber - recognizer not available")
            throw TranscriptionError.modelNotLoaded
        }

        // Log recognizer capabilities
        print("DEBUG: SpeechTranscriber - recognizer available")
        print("DEBUG: SpeechTranscriber - supportsOnDeviceRecognition: \(recognizer.supportsOnDeviceRecognition)")

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw TranscriptionError.transcriptionFailed("Could not create recognition request")
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true

        // Note: Don't require on-device - it can silently fail if model isn't ready
        // Let the system choose the best option
        print("DEBUG: SpeechTranscriber - on-device available: \(recognizer.supportsOnDeviceRecognition)")

        appendCount = 0  // Reset counter

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let error = error as NSError? {
                // "No speech detected" is code 1110 - this is normal during silence, don't stop
                let isNoSpeechError = error.domain == "kAFAssistantErrorDomain" && error.code == 1110

                if !isNoSpeechError {
                    print("DEBUG: SpeechTranscriber - error: \(error.localizedDescription) (code: \(error.code), domain: \(error.domain))")
                    // Only clean up on fatal errors, not "no speech detected"
                    self?.recognitionRequest = nil
                    self?.recognitionTask = nil
                }
            }

            if let result = result {
                let text = result.bestTranscription.formattedString
                let isFinal = result.isFinal
                print("DEBUG: SpeechTranscriber - got result: '\(text.prefix(30))...' isFinal=\(isFinal)")
                self?.onTranscription?(text, isFinal)

                if isFinal {
                    self?.recognitionRequest = nil
                    self?.recognitionTask = nil
                }
            }
        }
        print("DEBUG: SpeechTranscriber - recognition task started")
    }

    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        appendCount += 1
        if appendCount % 50 == 0 {
            let taskState = recognitionTask?.state.rawValue ?? -1
            let hasRequest = recognitionRequest != nil
            print("DEBUG: SpeechTranscriber - appended \(appendCount) buffers, taskState=\(taskState), hasRequest=\(hasRequest)")
        }
        recognitionRequest?.append(buffer)
    }

    func stopTranscribing() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }
}
