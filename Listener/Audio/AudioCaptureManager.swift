import Foundation
import AVFoundation

class AudioCaptureManager {
    private let recordingState: RecordingState
    private let transcriptionStore: TranscriptionStore

    private var microphoneCapture: MicrophoneCapture?
    private var systemAudioCapture: Any?

    private let micTranscriber = SpeechTranscriber()
    private let systemTranscriber = SpeechTranscriber()

    private var lastMicText = ""
    private var lastSystemText = ""

    init(recordingState: RecordingState, transcriptionStore: TranscriptionStore) {
        self.recordingState = recordingState
        self.transcriptionStore = transcriptionStore
        setupAudioCapture()
        setupTranscribers()
    }

    private func setupAudioCapture() {
        do {
            let micCapture = try MicrophoneCapture()
            micCapture.onAudioBuffer = { [weak self] buffer, source in
                self?.handleAudioBuffer(buffer, from: source)
            }
            self.microphoneCapture = micCapture
        } catch {
            print("Failed to setup microphone: \(error)")
        }

        if #available(macOS 12.3, *) {
            let sysCapture = SystemAudioCapture()
            sysCapture.onAudioBuffer = { [weak self] buffer, source in
                self?.handleAudioBuffer(buffer, from: source)
            }
            self.systemAudioCapture = sysCapture
        }
    }

    private func setupTranscribers() {
        micTranscriber.onTranscription = { [weak self] text, isFinal in
            guard let self = self, !text.isEmpty else { return }
            DispatchQueue.main.async {
                if text != self.lastMicText {
                    let newText = String(text.dropFirst(self.lastMicText.count))
                    if !newText.trimmingCharacters(in: .whitespaces).isEmpty {
                        self.recordingState.appendTranscript(newText.trimmingCharacters(in: .whitespaces), speaker: .you)
                    }
                    self.lastMicText = text
                }
            }
        }

        systemTranscriber.onTranscription = { [weak self] text, isFinal in
            guard let self = self, !text.isEmpty else { return }
            DispatchQueue.main.async {
                if text != self.lastSystemText {
                    let newText = String(text.dropFirst(self.lastSystemText.count))
                    if !newText.trimmingCharacters(in: .whitespaces).isEmpty {
                        self.recordingState.appendTranscript(newText.trimmingCharacters(in: .whitespaces), speaker: .other)
                    }
                    self.lastSystemText = text
                }
            }
        }
    }

    func startRecording() {
        Task {
            // Request permissions
            let micPermission = await microphoneCapture?.requestPermission() ?? false
            guard micPermission else {
                print("Microphone permission denied")
                return
            }

            let speechPermission = await micTranscriber.requestPermission()
            guard speechPermission else {
                print("Speech recognition permission denied")
                return
            }

            if #available(macOS 12.3, *), let sysCapture = systemAudioCapture as? SystemAudioCapture {
                let _ = await sysCapture.requestPermission()
            }

            do {
                // Reset state
                lastMicText = ""
                lastSystemText = ""

                // Start transcribers
                try micTranscriber.startTranscribing()
                try systemTranscriber.startTranscribing()

                // Start audio capture
                try microphoneCapture?.start()

                if #available(macOS 12.3, *), let sysCapture = systemAudioCapture as? SystemAudioCapture {
                    try await sysCapture.start()
                }

                await MainActor.run {
                    recordingState.startRecording()
                }
            } catch {
                print("Failed to start: \(error)")
                await MainActor.run { recordingState.stopRecording() }
            }
        }
    }

    func stopRecording() {
        Task {
            // Stop audio capture
            microphoneCapture?.stop()

            if #available(macOS 12.3, *), let sysCapture = systemAudioCapture as? SystemAudioCapture {
                try? await sysCapture.stop()
            }

            // Stop transcribers
            micTranscriber.stopTranscribing()
            systemTranscriber.stopTranscribing()

            // Small delay to let final transcriptions come through
            try? await Task.sleep(nanoseconds: 500_000_000)

            await MainActor.run {
                let transcript = recordingState.currentTranscript
                let duration = recordingState.recordingDuration
                recordingState.stopRecording()

                if !transcript.isEmpty {
                    let transcription = Transcription(content: transcript, duration: duration)
                    transcriptionStore.save(transcription)
                }
            }
        }
    }

    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer, from source: AudioSource) {
        switch source {
        case .microphone:
            micTranscriber.appendAudioBuffer(buffer)
        case .system:
            systemTranscriber.appendAudioBuffer(buffer)
        }
    }
}
