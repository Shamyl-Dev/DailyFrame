import Foundation
import SwiftData

@Model
final class DiaryEntry: Identifiable {
    var id: UUID = UUID()
    var date: Date
    var videoURL: URL?
    var transcription: String?
    var thumbnailData: Data?
    var duration: TimeInterval?
    var mood: String? // 👈 Add this line
    
    init(date: Date) {
        self.date = date
        self.videoURL = nil
        self.transcription = nil
        self.thumbnailData = nil
        self.duration = nil
        self.mood = nil // 👈 Add this line
    }
}