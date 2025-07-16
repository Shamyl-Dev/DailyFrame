import Foundation
import NaturalLanguage

@MainActor
class AIAnalysisService: ObservableObject {
    static let shared = AIAnalysisService()
    
    func analyzeSentiment(text: String) -> (score: Double, label: String) {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text

        let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        let score = Double(sentiment?.rawValue ?? "0") ?? 0.0

        let label: String
        if score > 0.15 {
            label = "Positive"
        } else if score < -0.5 {
            label = "Negative"
        } else {
            label = "Neutral"
        }
        return (score, label)
    }
}