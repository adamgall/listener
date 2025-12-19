import Foundation
import AVFoundation

/// Placeholder Whisper transcriber - replace with actual whisper.cpp integration
actor WhisperTranscriber: TranscriptionServiceProtocol {
    private let config: TranscriptionConfig
    private var isCancelled = false

    init(config: TranscriptionConfig = TranscriptionConfig()) {
        self.config = config
    }

    func transcribe(audioBuffer: [Float]) async throws -> String {
        guard !audioBuffer.isEmpty else {
            throw TranscriptionError.invalidAudioData
        }

        isCancelled = false

        // TODO: Integrate whisper.cpp here
        // For now, return placeholder
        try await Task.sleep(nanoseconds: 100_000_000)

        if isCancelled {
            throw TranscriptionError.cancelled
        }

        return "[Whisper transcription - integration pending]"
    }

    func transcribe(audioFileURL url: URL) async throws -> String {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw TranscriptionError.fileNotFound
        }

        let buffer = try await loadAudioFile(url: url)
        return try await transcribe(audioBuffer: buffer)
    }

    func cancelTranscription() async {
        isCancelled = true
    }

    private func loadAudioFile(url: URL) async throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = UInt32(file.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw TranscriptionError.invalidAudioData
        }

        try file.read(into: buffer)

        guard let floatData = buffer.floatChannelData else {
            throw TranscriptionError.invalidAudioData
        }

        return Array(UnsafeBufferPointer(start: floatData[0], count: Int(buffer.frameLength)))
    }
}

/// Mock transcriber for testing
actor MockTranscriber: TranscriptionServiceProtocol {
    private let mockText: String
    private var isCancelled = false

    init(mockText: String = "This is mock transcription.") {
        self.mockText = mockText
    }

    func transcribe(audioBuffer: [Float]) async throws -> String {
        try await Task.sleep(nanoseconds: 500_000_000)
        return isCancelled ? "" : mockText
    }

    func transcribe(audioFileURL url: URL) async throws -> String {
        try await Task.sleep(nanoseconds: 500_000_000)
        return "\(mockText) [\(url.lastPathComponent)]"
    }

    func cancelTranscription() async {
        isCancelled = true
    }
}
