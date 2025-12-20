import Foundation
import AVFoundation

class AudioCaptureManager {
    private let recordingState: RecordingState
    private let transcriptionStore: TranscriptionStore

    private var microphoneCapture: MicrophoneCapture?
    private var systemAudioCapture: Any?

    private let micTranscriber = SpeechTranscriber()
    private let systemTranscriber = SpeechTranscriber()
    private let speakerDiarizer = SpeakerDiarizer()

    private var lastMicText = ""
    private var lastMicWordSegments: [WordSegment] = []
    private var lastSystemText = ""
    private var currentSpeakerId = "SPEAKER_0"
    private var speakerIdMap: [String: Int] = [:]
    private var nextSpeakerNumber = 1
    private var diarizationTimer: Timer?
    private var diarizationAvailable = false

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
        micTranscriber.onTranscription = { [weak self] text, wordSegments, isFinal in
            print("DEBUG: micTranscriber got: '\(text.prefix(80))...' isFinal=\(isFinal), words=\(wordSegments.count)")
            guard let self = self else { return }

            // Only update if we have actual text (not empty/shorter than what we have)
            // This prevents losing text when stop triggers an empty final result
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty, trimmedText.count >= self.lastMicText.count else {
                print("DEBUG: Ignoring empty/shorter result")
                return
            }

            DispatchQueue.main.async {
                self.lastMicText = trimmedText
                self.lastMicWordSegments = wordSegments

                // Use diarization to determine speaker
                // Assume first speaker detected (usually '1') is "You"
                let speaker: Speaker
                if self.currentSpeakerId == "1" || self.currentSpeakerId == "SPEAKER_0" {
                    speaker = .you
                } else {
                    speaker = .speaker(self.getSpeakerNumber(for: self.currentSpeakerId))
                }
                print("DEBUG: Current speaker: \(self.currentSpeakerId) -> \(speaker)")
                self.recordingState.setTranscript(trimmedText, speaker: speaker)
            }
        }

        systemTranscriber.onTranscription = { [weak self] text, _, isFinal in
            print("DEBUG: systemTranscriber got: '\(text.prefix(80))...' isFinal=\(isFinal)")
            guard let self = self, !text.isEmpty else { return }
            DispatchQueue.main.async {
                self.lastSystemText = text
            }
        }
    }

    private func getSpeakerNumber(for speakerId: String) -> Int {
        if let existing = speakerIdMap[speakerId] {
            return existing
        }
        let num = nextSpeakerNumber
        speakerIdMap[speakerId] = num
        nextSpeakerNumber += 1
        return num
    }

    private func alignWordsToSpeakers(
        words: [WordSegment],
        speakers: [(speakerId: String, startTime: Float, endTime: Float)]
    ) -> [(word: String, speakerId: String)] {
        guard !speakers.isEmpty else {
            // No diarization data - assign all words to "You"
            return words.map { ($0.word, "1") }
        }

        var result: [(word: String, speakerId: String)] = []
        var lastSpeakerId = speakers.first?.speakerId ?? "1"

        for word in words {
            let wordMidpoint = Float(word.timestamp + word.duration / 2)

            // Find which speaker segment contains this word's midpoint
            var foundSpeaker: String?
            for segment in speakers {
                if wordMidpoint >= segment.startTime && wordMidpoint <= segment.endTime {
                    foundSpeaker = segment.speakerId
                    break
                }
            }

            let speakerId = foundSpeaker ?? lastSpeakerId
            result.append((word.word, speakerId))
            lastSpeakerId = speakerId
        }

        return result
    }

    private func formatAlignedTranscript(
        alignedWords: [(word: String, speakerId: String)]
    ) -> String {
        guard !alignedWords.isEmpty else { return "" }

        var result = ""
        var currentSpeaker = ""
        var currentWords: [String] = []

        for (word, speakerId) in alignedWords {
            if speakerId != currentSpeaker {
                // Flush previous speaker's words
                if !currentWords.isEmpty {
                    let label = currentSpeaker == "1" ? "You" : "Speaker \(currentSpeaker)"
                    if !result.isEmpty { result += "\n\n" }
                    result += "[\(label)]: \(currentWords.joined(separator: " "))"
                }
                currentSpeaker = speakerId
                currentWords = [word]
            } else {
                currentWords.append(word)
            }
        }

        // Flush final speaker's words
        if !currentWords.isEmpty {
            let label = currentSpeaker == "1" ? "You" : "Speaker \(currentSpeaker)"
            if !result.isEmpty { result += "\n\n" }
            result += "[\(label)]: \(currentWords.joined(separator: " "))"
        }

        return result
    }

    private func updateDiarization() {
        let segments = speakerDiarizer.processDiarization()
        if !segments.isEmpty {
            print("DEBUG: Diarization found \(segments.count) segments")
            for segment in segments {
                print("DEBUG:   Speaker '\(segment.speakerId)' from \(String(format: "%.1f", segment.startTime))s to \(String(format: "%.1f", segment.endTime))s")
            }
        }
        if let lastSegment = segments.last {
            currentSpeakerId = lastSegment.speakerId
        }
    }

    func startRecording() {
        print("DEBUG: startRecording called")
        Task {
            print("DEBUG: Task started")
            // Request permissions
            let micPermission = await microphoneCapture?.requestPermission() ?? false
            print("DEBUG: mic permission = \(micPermission)")
            guard micPermission else {
                print("Microphone permission denied")
                return
            }

            let speechPermission = await micTranscriber.requestPermission()
            print("DEBUG: speech permission = \(speechPermission)")
            guard speechPermission else {
                print("Speech recognition permission denied")
                return
            }

            if #available(macOS 12.3, *), let sysCapture = systemAudioCapture as? SystemAudioCapture {
                let _ = await sysCapture.requestPermission()
            }

            do {
                // Try to initialize speaker diarizer (optional - may fail if no network)
                do {
                    try await speakerDiarizer.initialize()
                    diarizationAvailable = true
                } catch {
                    print("Diarization unavailable (will use generic speaker labels): \(error)")
                    diarizationAvailable = false
                }

                // Reset state
                lastMicText = ""
                lastMicWordSegments = []
                lastSystemText = ""
                currentSpeakerId = "SPEAKER_0"
                speakerIdMap.removeAll()
                nextSpeakerNumber = 1
                speakerDiarizer.reset()

                // Start mic transcriber
                try micTranscriber.startTranscribing()

                // Start audio capture
                try microphoneCapture?.start()

                // Try system audio (optional - may fail)
                var systemAudioWorking = false
                if #available(macOS 12.3, *), let sysCapture = systemAudioCapture as? SystemAudioCapture {
                    do {
                        try await sysCapture.start()
                        print("DEBUG: System audio capture started")
                        // Only start system transcriber if capture succeeded
                        try systemTranscriber.startTranscribing()
                        systemAudioWorking = true
                    } catch {
                        print("System audio unavailable (mic-only mode): \(error.localizedDescription)")
                    }
                }
                print("DEBUG: System audio working: \(systemAudioWorking)")

                await MainActor.run {
                    recordingState.startRecording()
                    print("DEBUG: Recording started!")

                    // Start periodic diarization updates if available
                    if self.diarizationAvailable {
                        self.diarizationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                            self?.updateDiarization()
                        }
                    }
                }
            } catch {
                print("Failed to start: \(error)")
                await MainActor.run { recordingState.stopRecording() }
            }
        }
    }

    func stopRecording() {
        Task {
            // Stop diarization timer
            await MainActor.run {
                diarizationTimer?.invalidate()
                diarizationTimer = nil
            }

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

            // Run final diarization pass
            var diarizationSegments: [(speakerId: String, startTime: Float, endTime: Float)] = []
            if diarizationAvailable {
                print("DEBUG: Running final diarization...")
                diarizationSegments = speakerDiarizer.processDiarization()
                print("DEBUG: Final diarization found \(diarizationSegments.count) speaker segments")
                for segment in diarizationSegments {
                    print("DEBUG:   Speaker '\(segment.speakerId)' from \(String(format: "%.1f", segment.startTime))s to \(String(format: "%.1f", segment.endTime))s")
                }

                // Count unique speakers
                let uniqueSpeakers = Set(diarizationSegments.map { $0.speakerId })
                print("DEBUG: Identified \(uniqueSpeakers.count) unique speaker(s): \(uniqueSpeakers)")
            }

            await MainActor.run {
                let duration = recordingState.recordingDuration
                recordingState.stopRecording()

                // Format transcript with word-level speaker attribution
                var transcript = ""
                let wordSegments = self.lastMicWordSegments

                if !wordSegments.isEmpty {
                    let uniqueSpeakers = Set(diarizationSegments.map { $0.speakerId }).sorted()
                    let speakerCount = uniqueSpeakers.count

                    if speakerCount <= 1 {
                        // Single speaker - label as "You"
                        let text = wordSegments.map { $0.word }.joined(separator: " ")
                        transcript = "[You]: \(text)"
                    } else {
                        // Multiple speakers - align words to speakers
                        print("DEBUG: Aligning \(wordSegments.count) words to \(diarizationSegments.count) speaker segments")
                        let alignedWords = self.alignWordsToSpeakers(
                            words: wordSegments,
                            speakers: diarizationSegments
                        )
                        transcript = self.formatAlignedTranscript(alignedWords: alignedWords)
                    }
                }

                print("DEBUG: Saving transcript with \(transcript.count) chars, duration=\(duration)")

                if !transcript.isEmpty {
                    let transcription = Transcription(content: transcript, duration: duration)
                    transcriptionStore.save(transcription)
                    print("DEBUG: Transcription saved!")
                } else {
                    print("DEBUG: Transcript was empty, not saving")
                }
            }
        }
    }

    private var bufferCount = 0

    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer, from source: AudioSource) {
        bufferCount += 1
        if bufferCount % 100 == 0 {
            print("DEBUG: Received \(bufferCount) audio buffers from \(source)")
        }
        switch source {
        case .microphone:
            micTranscriber.appendAudioBuffer(buffer)
            // Also feed to diarizer for speaker identification
            if diarizationAvailable {
                speakerDiarizer.appendAudioBuffer(buffer)
            }
        case .system:
            systemTranscriber.appendAudioBuffer(buffer)
            speakerDiarizer.appendAudioBuffer(buffer)
        }
    }
}
