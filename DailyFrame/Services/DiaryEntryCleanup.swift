import Foundation
import SwiftData

func removeOrphanedDiaryEntries(context: ModelContext) {
    let fetchDescriptor = FetchDescriptor<DiaryEntry>()
    do {
        let entries = try context.fetch(fetchDescriptor)
        for entry in entries {
            let hasVideo = entry.videoURL != nil && FileManager.default.fileExists(atPath: entry.videoURL!.path)
            let hasTranscript = !(entry.transcription?.isEmpty ?? true)
            // Remove if no video, no transcript, or video file missing
            if (!hasVideo && !hasTranscript) || (entry.videoURL != nil && !hasVideo) {
                context.delete(entry)
            }
        }
        try context.save()
        print("Orphaned diary entries removed.")
    } catch {
        print("Error cleaning orphaned diary entries: \(error)")
    }
}