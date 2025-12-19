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

    func start() throws {
        guard !isRunning else { return }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        audioConverter = AVAudioConverter(from: inputFormat, to: targetFormat)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self, let convertedBuffer = self.convert(buffer: buffer) else { return }
            self.onAudioBuffer?(convertedBuffer, .microphone)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRunning = true
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
