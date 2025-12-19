import Foundation

protocol TranscriptionServiceProtocol {
    func transcribe(audioBuffer: [Float]) async throws -> String
    func transcribe(audioFileURL url: URL) async throws -> String
    func cancelTranscription() async
}

struct TranscriptionResult: Sendable {
    let text: String
    let isFinal: Bool
    let timestamp: TimeInterval?
    let confidence: Float?

    init(text: String, isFinal: Bool = true, timestamp: TimeInterval? = nil, confidence: Float? = nil) {
        self.text = text
        self.isFinal = isFinal
        self.timestamp = timestamp
        self.confidence = confidence
    }
}

enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case modelLoadFailed(String)
    case invalidAudioFormat
    case invalidAudioData
    case transcriptionFailed(String)
    case cancelled
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "Model not loaded"
        case .modelLoadFailed(let r): return "Model load failed: \(r)"
        case .invalidAudioFormat: return "Invalid audio format"
        case .invalidAudioData: return "Invalid audio data"
        case .transcriptionFailed(let r): return "Transcription failed: \(r)"
        case .cancelled: return "Cancelled"
        case .fileNotFound: return "File not found"
        }
    }
}

struct TranscriptionConfig: Sendable {
    let sampleRate: Int
    let channels: Int
    let language: String?
    let enableTimestamps: Bool

    init(sampleRate: Int = 16000, channels: Int = 1, language: String? = nil, enableTimestamps: Bool = false) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.language = language
        self.enableTimestamps = enableTimestamps
    }
}
