import Foundation
import Combine

class TranscriptionStore: ObservableObject {
    @Published var transcriptions: [Transcription] = []

    private let saveURL: URL

    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        saveURL = documentsPath.appendingPathComponent("listener_transcriptions.json")
        load()
    }

    func save(_ transcription: Transcription) {
        transcriptions.insert(transcription, at: 0)
        persist()
    }

    func update(_ transcription: Transcription) {
        if let index = transcriptions.firstIndex(where: { $0.id == transcription.id }) {
            var updated = transcription
            updated.updatedAt = Date()
            transcriptions[index] = updated
            persist()
        }
    }

    func delete(_ transcription: Transcription) {
        transcriptions.removeAll { $0.id == transcription.id }
        persist()
    }

    func delete(at offsets: IndexSet) {
        transcriptions.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(transcriptions)
            try data.write(to: saveURL)
        } catch {
            print("Failed to save transcriptions: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return }

        do {
            let data = try Data(contentsOf: saveURL)
            transcriptions = try JSONDecoder().decode([Transcription].self, from: data)
        } catch {
            print("Failed to load transcriptions: \(error)")
        }
    }
}
