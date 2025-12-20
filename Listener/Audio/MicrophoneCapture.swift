import Foundation
import AVFoundation

enum MicrophoneCaptureError: Error {
    case permissionDenied
    case audioEngineSetupFailed
    case invalidAudioFormat
}

enum AudioSource {
    case microphone
    case system
}

class MicrophoneCapture {
    private let audioEngine = AVAudioEngine()
    private var audioConverter: AVAudioConverter?
    private var isRunning = false
    private let targetFormat: AVAudioFormat

    var onAudioBuffer: ((AVAudioPCMBuffer, AudioSource) -> Void)?

    init() throws {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw MicrophoneCaptureError.invalidAudioFormat
        }
        self.targetFormat = format
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private var peakLevel: Float = 0
    private var levelLogCount = 0

    func start() throws {
        guard !isRunning else { return }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Log input device info
        let audioSession = audioEngine.inputNode.auAudioUnit
        print("DEBUG: Audio input node: \(inputNode)")
        print("DEBUG: Mic input format: \(inputFormat)")
        print("DEBUG: Sample rate: \(inputFormat.sampleRate), channels: \(inputFormat.channelCount)")

        audioConverter = AVAudioConverter(from: inputFormat, to: targetFormat)
        print("DEBUG: Audio converter created: \(audioConverter != nil)")

        peakLevel = 0
        levelLogCount = 0

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
            guard let self = self else { return }

            // Check audio level
            if let channelData = buffer.floatChannelData?[0] {
                var sum: Float = 0
                var maxSample: Float = 0
                for i in 0..<Int(buffer.frameLength) {
                    let sample = abs(channelData[i])
                    sum += sample
                    if sample > maxSample { maxSample = sample }
                }
                let avgLevel = sum / Float(buffer.frameLength)

                // Track peak
                if maxSample > self.peakLevel {
                    self.peakLevel = maxSample
                }

                // Log periodically with more info
                self.levelLogCount += 1
                if self.levelLogCount % 50 == 0 {
                    print("DEBUG: Audio levels - avg:\(String(format: "%.4f", avgLevel)) max:\(String(format: "%.4f", maxSample)) peak:\(String(format: "%.4f", self.peakLevel))")
                }

                // Alert if we see speech-level audio (> 0.1)
                if maxSample > 0.1 {
                    print("DEBUG: 🎤 SPEECH detected! level=\(String(format: "%.3f", maxSample))")
                }
            }

            guard let convertedBuffer = self.convert(buffer: buffer) else {
                print("DEBUG: Tap callback - conversion failed")
                return
            }
            self.onAudioBuffer?(convertedBuffer, .microphone)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRunning = true
        print("DEBUG: Mic audio engine started successfully")
    }

    func stop() {
        guard isRunning else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRunning = false
    }

    private func convert(buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let converter = audioConverter else { return nil }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCapacity
        ) else { return nil }

        var error: NSError?
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        if error != nil { return nil }
        outputBuffer.frameLength = outputFrameCapacity
        return outputBuffer
    }
}
