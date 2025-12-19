import Foundation
import AVFoundation
import FluidAudio

class SpeakerDiarizer {
    private var diarizer: DiarizerManager?
    private var models: DiarizerModels?
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()

    var onSpeakerIdentified: ((Int, TimeInterval, TimeInterval) -> Void)?

    private var isInitialized = false

    func initialize() async throws {
        guard !isInitialized else { return }

        models = try await DiarizerModels.downloadIfNeeded()
        diarizer = DiarizerManager()
        diarizer?.initialize(models: models!)
        isInitialized = true
    }

    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let floatData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)

        bufferLock.lock()
        for i in 0..<frameCount {
            audioBuffer.append(floatData[i])
        }
        bufferLock.unlock()
    }

    func processDiarization() -> [(speakerId: String, startTime: Float, endTime: Float)] {
        guard let diarizer = diarizer else { return [] }

        bufferLock.lock()
        let samples = audioBuffer
        bufferLock.unlock()

        guard !samples.isEmpty else { return [] }

        do {
            let result = try diarizer.performCompleteDiarization(samples)
            return result.segments.map { segment in
                (speakerId: segment.speakerId,
                 startTime: segment.startTimeSeconds,
                 endTime: segment.endTimeSeconds)
            }
        } catch {
            print("Diarization error: \(error)")
            return []
        }
    }

    func reset() {
        bufferLock.lock()
        audioBuffer.removeAll()
        bufferLock.unlock()
    }
}
