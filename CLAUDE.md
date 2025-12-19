# Listener - macOS Audio Transcription App

This project uses **bd (beads)** for issue tracking. See AGENTS.md for workflow details.

## Project Overview

Listener is a macOS menubar app that:
- Lives in the system menubar with a toggle to start/stop recording
- Captures both microphone input (you) and system audio output (others)
- Transcribes audio in real-time using whisper.cpp
- Labels speakers based on audio source (You vs Others)
- Saves transcriptions with RUD (Read, Update, Delete) operations
- Displays transcriptions in a SwiftUI window

## Tech Stack

- **Language**: Swift
- **UI Framework**: SwiftUI
- **Audio Capture**: AVAudioEngine (mic), ScreenCaptureKit (system audio)
- **Transcription**: whisper.cpp (local, offline)
- **Minimum OS**: macOS 13.0

## Project Structure

```
Listener/
├── ListenerApp.swift          # App entry, AppDelegate, menubar setup
├── ContentView.swift          # Main UI with NavigationSplitView
├── Models/
│   ├── RecordingState.swift   # Observable recording state
│   ├── Transcription.swift    # Transcription data model
│   └── TranscriptionStore.swift # Persistence layer
├── Audio/
│   ├── AudioCaptureManager.swift   # Coordinates mic + system audio
│   ├── MicrophoneCapture.swift     # AVAudioEngine mic capture
│   └── SystemAudioCapture.swift    # ScreenCaptureKit system audio
├── Transcription/
│   ├── TranscriptionService.swift  # Protocol for transcription
│   └── WhisperTranscriber.swift    # whisper.cpp integration
├── Info.plist
└── Listener.entitlements
```

## Building

Open `Listener.xcodeproj` in Xcode and build. Requires:
- Xcode 15+
- macOS 13.0+ SDK
- Microphone permission
- Screen Recording permission (for system audio via ScreenCaptureKit)

## Key Decisions

1. **Speaker labeling**: We differentiate by audio source - mic input is "You", system audio is "Others". This is simpler than full diarization and works well for the primary use case (recording calls/meetings).

2. **Local transcription**: Using whisper.cpp for privacy and offline capability. No API keys needed.

3. **No dock icon during recording**: App uses LSUIElement but shows window on demand.

4. **Persistence**: Simple JSON file storage in Documents folder. SwiftData could be added later if needed.

## Development Workflow

1. Check `bd ready` for available tasks
2. Claim with `bd update <id> --status in_progress`
3. Implement the feature
4. Close with `bd close <id>`
5. Run `bd sync` at session end

## Current Epic

`listener-ede` - Build macOS Menubar Transcription App

See `bd list --parent listener-ede` for subtasks.
