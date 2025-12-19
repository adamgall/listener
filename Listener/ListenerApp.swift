import SwiftUI

@main
struct ListenerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.recordingState)
                .environmentObject(appDelegate.transcriptionStore)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 600, height: 500)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var recordingState = RecordingState()
    var transcriptionStore = TranscriptionStore()
    var audioCapture: AudioCaptureManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        audioCapture = AudioCaptureManager(recordingState: recordingState, transcriptionStore: transcriptionStore)
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Listener")
        }

        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Start Recording", action: #selector(toggleRecording), keyEquivalent: "r")
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let openWindowItem = NSMenuItem(title: "Open Listener", action: #selector(openMainWindow), keyEquivalent: "o")
        menu.addItem(openWindowItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu

        // Observe recording state changes to update menu
        recordingState.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                self?.updateMenuBarIcon(isRecording: isRecording)
                toggleItem.title = isRecording ? "Stop Recording" : "Start Recording"
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    private func updateMenuBarIcon(isRecording: Bool) {
        if let button = statusItem?.button {
            let symbolName = isRecording ? "waveform.circle.fill" : "waveform"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Listener")
            button.image?.isTemplate = true
        }
    }

    @objc private func toggleRecording() {
        if recordingState.isRecording {
            audioCapture?.stopRecording()
        } else {
            audioCapture?.startRecording()
        }
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

import Combine
