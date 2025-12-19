# Listener - macOS Audio Transcription App

## Project Overview

Listener is a macOS menubar app that:
- Lives in the system menubar with a toggle to start/stop recording
- Captures both microphone input (you) and system audio output (others)
- Transcribes audio in real-time using Apple Speech framework
- Identifies different speakers via FluidAudio speaker diarization
- Saves transcriptions with RUD (Read, Update, Delete) operations
- Displays transcriptions in a SwiftUI window

## Tech Stack

- **Language**: Swift
- **UI Framework**: SwiftUI
- **Audio Capture**: AVAudioEngine (mic), ScreenCaptureKit (system audio)
- **Transcription**: Apple Speech framework (SFSpeechRecognizer)
- **Speaker Diarization**: FluidAudio (Core ML)
- **Minimum OS**: macOS 14.0

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
│   ├── AudioCaptureManager.swift   # Coordinates mic + system audio + diarization
│   ├── MicrophoneCapture.swift     # AVAudioEngine mic capture
│   └── SystemAudioCapture.swift    # ScreenCaptureKit system audio
├── Transcription/
│   ├── SpeechTranscriber.swift     # Apple Speech framework wrapper
│   ├── SpeakerDiarizer.swift       # FluidAudio diarization wrapper
│   ├── TranscriptionService.swift  # Protocol for transcription
│   └── WhisperTranscriber.swift    # (unused) whisper.cpp integration
├── Info.plist
└── Listener.entitlements
```

## Building

Open `Listener.xcodeproj` in Xcode and build. Requires:
- Xcode 15+
- macOS 14.0+ SDK
- Microphone permission
- Speech recognition permission
- Screen Recording permission (for system audio via ScreenCaptureKit)

## Key Decisions

1. **Speaker identification**: Mic input = "You", system audio uses FluidAudio diarization to identify Speaker 1, Speaker 2, etc.

2. **Local transcription**: Using Apple Speech framework. FluidAudio runs diarization on-device via Core ML.

3. **No dock icon during recording**: App uses LSUIElement but shows window on demand.

4. **Persistence**: Simple JSON file storage in Documents folder.

---

## Issue Tracking with bd (beads)

**IMPORTANT**: This project uses **bd (beads)** for ALL issue tracking.

### Quick Commands

```bash
bd ready              # Show unblocked issues ready to work
bd create "Title" -t task -p 1    # Create issue (priority 0-4)
bd update <id> --status in_progress    # Claim work
bd close <id>         # Complete issue
bd sync               # Sync with git at session end
```

### Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item
- `epic` - Large feature with subtasks
- `chore` - Maintenance

### Priorities

- `0` - Critical
- `1` - High
- `2` - Medium (default)
- `3` - Low
- `4` - Backlog

### Workflow

1. `bd ready` - Find available work
2. `bd update <id> --status in_progress` - Claim it
3. Implement the feature
4. `bd close <id>` - Complete
5. `bd sync` - Sync at session end
