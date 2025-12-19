import Foundation
import AVFoundation

class AudioCaptureManager {
    private let recordingState: RecordingState
    private let transcriptionStore: TranscriptionStore

    private var microphoneCapture: MicrophoneCapture?
    private var systemAudioCapture: Any? // Type-erased for @available check

    private var audioBuffers: [(buffer: AVAudioPCMBuffer, source: AudioSource)] = []
    private let bufferLock = NSLock()
    private var transcriptionTask: Task<Void, Never>?

    init(recordingState: RecordingState, transcriptionStore: TranscriptionStore) {
        self.recordingState = recordingState
        self.transcriptionStore = transcriptionStore
        setupAudioCapture()
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

    func startRecording() {
        Task {
            let micPermission = await microphoneCapture?.requestPermission() ?? false
            guard micPermission else {
                print("Microphone permission denied")
                return
            }

            if #available(macOS 12.3, *), let sysCapture = systemAudioCapture as? SystemAudioCapture {
                let _ = await sysCapture.requestPermission()
            }

            do {
                try microphoneCapture?.start()

                if #available(macOS 12.3, *), let sysCapture = systemAudioCapture as? SystemAudioCapture {
                    try await sysCapture.start()
                }

                await MainActor.run {
                    recordingState.startRecording()
                }

                startTranscriptionTask()
            } catch {
                print("Failed to start: \(error)")
                await MainActor.run { recordingState.stopRecording() }
            }
        }
    }

    func stopRecording() {
        Task {
            microphoneCapture?.stop()

            if #available(macOS 12.3, *), let sysCapture = systemAudioCapture as? SystemAudioCapture {
                try? await sysCapture.stop()
            }

            transcriptionTask?.cancel()
            transcriptionTask = nil

            await processRemainingBuffers()

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
        bufferLock.lock()
        defer { bufferLock.unlock() }
        audioBuffers.append((buffer: buffer, source: source))

        if audioBuffers.count > 160 {
            audioBuffers.removeFirst(audioBuffers.count - 160)
        }
    }

    private func startTranscriptionTask() {
        transcriptionTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await processAudioBuffers()
            }
        }
    }

    private func processAudioBuffers() async {
        bufferLock.lock()
        let buffersToProcess = audioBuffers
        audioBuffers.removeAll()
        bufferLock.unlock()

        guard !buffersToProcess.isEmpty else { return }

        // Stub transcription - replace with Whisper integration
        let micBuffers = buffersToProcess.filter { $0.source == .microphone }
        let systemBuffers = buffersToProcess.filter { $0.source == .system }

        await MainActor.run {
            if !micBuffers.isEmpty {
                recordingState.appendTranscript("[You speaking...]", speaker: .you)
            }
            if !systemBuffers.isEmpty {
                recordingState.appendTranscript("[Other speaking...]", speaker: .other)
            }
        }
    }

    private func processRemainingBuffers() async {
        await processAudioBuffers()
    }
}
