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
            self.recognitionTask = recognizer?.recognitionTask(with: request) { result, error in
                if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                } else if let error = error {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVAsset(url: videoURL)
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "Export", code: 1, userInfo: nil)
        }
        exporter.outputURL = outputURL
        exporter.outputFileType = .m4a
        exporter.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        await withCheckedContinuation { cont in
            exporter.exportAsynchronously {
                cont.resume()
            }
        }
        if exporter.status == .completed {
            return outputURL
        } else {
            throw exporter.error ?? NSError(domain: "Export", code: 2, userInfo: nil)
        }
    }
}