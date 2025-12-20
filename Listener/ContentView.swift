import SwiftUI
import AVFoundation
import Speech
import ScreenCaptureKit

struct ContentView: View {
    @EnvironmentObject var recordingState: RecordingState
    @EnvironmentObject var transcriptionStore: TranscriptionStore
    @State private var selectedTranscription: Transcription?
    var audioCapture: AudioCaptureManager?

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                RecordingHeader(recordingState: recordingState, transcriptionStore: transcriptionStore, audioCapture: audioCapture)
                Divider()
                TranscriptionsList(
                    transcriptions: transcriptionStore.transcriptions,
                    selectedTranscription: $selectedTranscription,
                    onDelete: transcriptionStore.delete
                )
            }
            .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
        } detail: {
            if recordingState.isRecording {
                LiveTranscriptionView(recordingState: recordingState)
            } else if let transcription = selectedTranscription {
                TranscriptionDetailView(
                    transcription: transcription,
                    onUpdate: transcriptionStore.update
                )
            } else {
                EmptyDetailView()
            }
        }
    }
}

struct RecordingHeader: View {
    @ObservedObject var recordingState: RecordingState
    @ObservedObject var transcriptionStore: TranscriptionStore
    var audioCapture: AudioCaptureManager?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(recordingState.isRecording ? Color.red : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(recordingState.isRecording ? "Recording" : "Stopped")
                            .font(.headline)
                    }
                    if recordingState.isRecording {
                        Text(formatDuration(recordingState.recordingDuration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                Spacer()
                Button(action: toggleRecording) {
                    Image(systemName: recordingState.isRecording ? "stop.circle.fill" : "record.circle")
                        .font(.system(size: 32))
                        .foregroundColor(recordingState.isRecording ? .red : .blue)
                }
                .buttonStyle(.plain)
            }
            PermissionStatusView()
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func toggleRecording() {
        print("DEBUG: toggleRecording called, audioCapture = \(String(describing: audioCapture))")
        if recordingState.isRecording {
            audioCapture?.stopRecording()
        } else {
            audioCapture?.startRecording()
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct TranscriptionsList: View {
    let transcriptions: [Transcription]
    @Binding var selectedTranscription: Transcription?
    let onDelete: (Transcription) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Transcriptions")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

            if transcriptions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "mic.slash")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No transcriptions yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List(selection: $selectedTranscription) {
                    ForEach(transcriptions) { transcription in
                        TranscriptionRow(transcription: transcription)
                            .tag(transcription)
                            .contextMenu {
                                Button(role: .destructive) {
                                    onDelete(transcription)
                                    if selectedTranscription?.id == transcription.id {
                                        selectedTranscription = nil
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }
}

struct TranscriptionRow: View {
    let transcription: Transcription

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(transcription.title)
                .font(.subheadline)
                .lineLimit(1)
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(transcription.formattedDuration)
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            Text(transcription.content.prefix(100) + (transcription.content.count > 100 ? "..." : ""))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

struct LiveTranscriptionView: View {
    @ObservedObject var recordingState: RecordingState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.red)
                Text("Live Transcription")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Text(formatDuration(recordingState.recordingDuration))
                    .font(.title3)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            ScrollViewReader { proxy in
                ScrollView {
                    if recordingState.currentTranscript.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "waveform.circle")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("Listening...")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        Text(recordingState.currentTranscript)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("transcript")
                    }
                }
                .onChange(of: recordingState.currentTranscript) { _ in
                    withAnimation {
                        proxy.scrollTo("transcript", anchor: .bottom)
                    }
                }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct TranscriptionDetailView: View {
    let transcription: Transcription
    let onUpdate: (Transcription) -> Void

    @State private var editedTitle: String
    @State private var editedContent: String
    @State private var isEditing = false

    init(transcription: Transcription, onUpdate: @escaping (Transcription) -> Void) {
        self.transcription = transcription
        self.onUpdate = onUpdate
        _editedTitle = State(initialValue: transcription.title)
        _editedContent = State(initialValue: transcription.content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if isEditing {
                    TextField("Title", text: $editedTitle)
                        .textFieldStyle(.plain)
                        .font(.title2)
                        .fontWeight(.semibold)
                } else {
                    Text(transcription.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                Spacer()
                if isEditing {
                    Button("Cancel") {
                        editedTitle = transcription.title
                        editedContent = transcription.content
                        isEditing = false
                    }
                    .buttonStyle(.plain)
                    Button("Save") { saveChanges() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button { isEditing = true } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .buttonStyle(.plain)

                    Button { copyToClipboard() } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            HStack(spacing: 16) {
                Label(transcription.formattedDuration, systemImage: "clock")
                Label(formatDate(transcription.createdAt), systemImage: "calendar")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if isEditing {
                TextEditor(text: $editedContent)
                    .font(.body)
                    .padding(8)
            } else {
                ScrollView {
                    Text(transcription.content)
                        .font(.body)
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func saveChanges() {
        var updated = transcription
        updated.title = editedTitle
        updated.content = editedContent
        onUpdate(updated)
        isEditing = false
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcription.content, forType: .string)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.bubble")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text("No Selection")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("Select a transcription to view its details")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PermissionStatusView: View {
    @State private var micStatus: String = "..."
    @State private var speechStatus: String = "..."
    @State private var screenStatus: String = "..."

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Permissions").font(.caption).fontWeight(.semibold)
            HStack(spacing: 12) {
                PermissionBadge(name: "Mic", status: micStatus)
                PermissionBadge(name: "Speech", status: speechStatus)
                PermissionBadge(name: "Screen", status: screenStatus)
            }
        }
        .onAppear { checkPermissions() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkPermissions()
        }
    }

    private func checkPermissions() {
        // Microphone
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: micStatus = "OK"
        case .denied: micStatus = "NO"
        case .restricted: micStatus = "NO"
        case .notDetermined: micStatus = "?"
        @unknown default: micStatus = "?"
        }

        // Speech Recognition
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: speechStatus = "OK"
        case .denied: speechStatus = "NO"
        case .restricted: speechStatus = "NO"
        case .notDetermined: speechStatus = "?"
        @unknown default: speechStatus = "?"
        }

        // Screen Recording - check async
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                await MainActor.run {
                    screenStatus = content.displays.isEmpty ? "NO" : "OK"
                }
            } catch {
                await MainActor.run {
                    screenStatus = "NO"
                }
            }
        }
    }
}

struct PermissionBadge: View {
    let name: String
    let status: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(name)
                .font(.caption2)
        }
    }

    private var statusColor: Color {
        switch status {
        case "OK": return .green
        case "NO": return .red
        default: return .orange
        }
    }
}
