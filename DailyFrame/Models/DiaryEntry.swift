import Foundation
import SwiftData

@Model
final class DiaryEntry {
    var date: Date
    var videoURL: URL?
    var transcription: String?
    var thumbnailData: Data?
    var duration: TimeInterval?
    
    init(date: Date) {
        self.date = date
        self.videoURL = nil
        self.transcription = nil
        self.thumbnailData = nil
        self.duration = nil
    }
}