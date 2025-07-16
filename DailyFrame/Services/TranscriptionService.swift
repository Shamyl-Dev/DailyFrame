import Foundation
import Speech
import AVFoundation

@MainActor
class TranscriptionService: ObservableObject {
    @Published var transcript: String = ""
    private let recognizer = SFSpeechRecognizer()
    private var recognitionTask: SFSpeechRecognitionTask?

    func transcribeVideo(url: URL) async throws -> String {
        // 1. Extract audio from video
        let audioURL = try await extractAudio(from: url)
        defer {
            // Delete the temp audio file after transcription attempt
            try? FileManager.default.removeItem(at: audioURL)
        }
        // 2. Request permission
        let authStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard authStatus == .authorized else {
            throw NSError(domain: "Speech", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized"])
        }
        // 3. Create recognition request
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        // 4. Perform recognition
        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            self.recognitionTask = recognizer?.recognitionTask(with: request) { result, error in
                if didResume { return }
                if let result = result, result.isFinal {
                    didResume = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                } else if let error = error {
                    didResume = true
                    self.cancelRecognition() // Ensure cleanup
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: videoURL) // 1. Use AVURLAsset instead of AVAsset(url:)
        // 2. Use loadTracks(withMediaType:) async
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let hasAudio = !audioTracks.isEmpty
        if !hasAudio {
            throw NSError(domain: "Export", code: 3, userInfo: [NSLocalizedDescriptionKey: "No audio track found in video"])
        }
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "Export", code: 1, userInfo: nil)
        }
        exporter.outputURL = outputURL
        exporter.outputFileType = .m4a
        // 3. Use load(.duration) async
        let duration = try await asset.load(.duration)
        exporter.timeRange = CMTimeRange(start: .zero, duration: duration)
        // 4. Use export(to:as:) async throws instead of exportAsynchronously
        try await exporter.export(to: outputURL, as: .m4a)
        // 5. No need to check status or error, just return outputURL if no error thrown
        return outputURL
    }

    func cancelRecognition() {
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}