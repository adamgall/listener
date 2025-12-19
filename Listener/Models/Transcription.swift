import Foundation

struct Transcription: Identifiable, Codable, Hashable {
    static func == (lhs: Transcription, rhs: Transcription) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let id: UUID
    var title: String
    var content: String
    let createdAt: Date
    var updatedAt: Date
    let duration: TimeInterval

    init(id: UUID = UUID(), title: String? = nil, content: String, duration: TimeInterval) {
        self.id = id
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
        self.duration = duration

        // Generate title from first line or timestamp
        if let customTitle = title {
            self.title = customTitle
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            self.title = "Recording - \(formatter.string(from: createdAt))"
        }
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct TranscriptSegment: Codable {
    let speaker: String
    let text: String
    let timestamp: TimeInterval
}
