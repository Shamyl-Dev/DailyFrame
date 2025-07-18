import Foundation
import NaturalLanguage

// New data structures for insights
struct WeeklyInsights {
    let moodTrend: MoodTrend
    let keywordFrequency: [String: Int]
    let activityPatterns: [ActivityPattern]
    let reflectionPrompt: String
}

struct MoodTrend {
    let direction: TrendDirection
    let percentage: Int
    let emoji: String
}

struct ActivityPattern {
    let keyword: String
    let frequency: Int
    let daysActive: Int
    let sentiment: String
    let emoji: String
}

enum TrendDirection {
    case up, down, stable
}

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
    
    func generateLocalSummary(from transcript: String) -> String {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = transcript
        
        let sentences = tokenizer.tokens(for: transcript.startIndex..<transcript.endIndex).map {
            String(transcript[$0])
        }
        
        // Return first 2-3 most meaningful sentences
        return Array(sentences.prefix(3)).joined(separator: " ")
    }
    
    func extractKeywords(from transcript: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = transcript
        
        var keywords: [String] = []
        tagger.enumerateTags(in: transcript.startIndex..<transcript.endIndex, 
                            unit: .word, 
                            scheme: .lexicalClass) { tag, tokenRange in
            if tag == .noun || tag == .verb {
                let keyword = String(transcript[tokenRange])
                if keyword.count > 3 { // Filter short words
                    keywords.append(keyword)
                }
            }
            return true
        }
        return Array(Set(keywords)) // Remove duplicates
    }
    
    func generateWeeklyInsights(entries: [DiaryEntry]) -> WeeklyInsights {
        let lastWeekEntries = getLastWeekEntries(entries)
        let previousWeekEntries = getPreviousWeekEntries(entries)
        
        return WeeklyInsights(
            moodTrend: analyzeMoodTrend(current: lastWeekEntries, previous: previousWeekEntries),
            keywordFrequency: analyzeKeywordFrequency(entries: lastWeekEntries),
            activityPatterns: analyzeActivityPatterns(entries: lastWeekEntries),
            reflectionPrompt: generateReflectionPrompt(entries: lastWeekEntries)
        )
    }
    
    private func getLastWeekEntries(_ entries: [DiaryEntry]) -> [DiaryEntry] {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        
        return entries.filter { entry in
            entry.date >= weekAgo && entry.date <= now
        }.sorted { $0.date < $1.date }
    }
    
    private func getPreviousWeekEntries(_ entries: [DiaryEntry]) -> [DiaryEntry] {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        
        return entries.filter { entry in
            entry.date >= twoWeeksAgo && entry.date < weekAgo
        }
    }
    
    private func analyzeMoodTrend(current: [DiaryEntry], previous: [DiaryEntry]) -> MoodTrend {
        let currentPositive = current.filter { $0.mood == "Positive" }.count
        let currentTotal = current.count
        let currentRatio = currentTotal > 0 ? Double(currentPositive) / Double(currentTotal) : 0.0
        
        let previousPositive = previous.filter { $0.mood == "Positive" }.count
        let previousTotal = previous.count
        let previousRatio = previousTotal > 0 ? Double(previousPositive) / Double(previousTotal) : 0.0
        
        let change = currentRatio - previousRatio
        let percentage = Int(abs(change) * 100)
        
        if change > 0.05 {
            return MoodTrend(direction: .up, percentage: percentage, emoji: "🟢")
        } else if change < -0.05 {
            return MoodTrend(direction: .down, percentage: percentage, emoji: "🔴")
        } else {
            return MoodTrend(direction: .stable, percentage: 0, emoji: "🟡")
        }
    }
    
    private func analyzeKeywordFrequency(entries: [DiaryEntry]) -> [String: Int] {
        var keywordCounts: [String: Int] = [:]
        
        for entry in entries {
            guard let transcript = entry.transcription else { continue }
            let keywords = extractKeywords(from: transcript)
            
            for keyword in keywords {
                let lowercased = keyword.lowercased()
                keywordCounts[lowercased, default: 0] += 1
            }
        }
        
        // Return top 10 most frequent keywords - fix the Dictionary initializer
        return Dictionary(uniqueKeysWithValues: Array(keywordCounts.sorted { $0.value > $1.value }.prefix(10)))
    }
    
    private func analyzeActivityPatterns(entries: [DiaryEntry]) -> [ActivityPattern] {
        let activityKeywords = ["work", "exercise", "friends", "family", "sleep", "study", "cooking", "reading"]
        var patterns: [ActivityPattern] = []
        
        for keyword in activityKeywords {
            var frequency = 0
            var daysWithActivity = 0
            var positiveMentions = 0
            
            for entry in entries {
                guard let transcript = entry.transcription?.lowercased() else { continue }
                
                if transcript.contains(keyword) {
                    frequency += 1
                    daysWithActivity += 1
                    
                    if entry.mood == "Positive" {
                        positiveMentions += 1
                    }
                }
            }
            
            if frequency > 0 {
                let sentiment = positiveMentions > frequency / 2 ? "positive" : "neutral"
                let emoji = getEmojiForActivity(keyword)
                
                patterns.append(ActivityPattern(
                    keyword: keyword,
                    frequency: frequency,
                    daysActive: daysWithActivity,
                    sentiment: sentiment,
                    emoji: emoji
                ))
            }
        }
        
        return patterns.sorted { $0.frequency > $1.frequency }
    }
    
    private func getEmojiForActivity(_ activity: String) -> String {
        switch activity.lowercased() {
        case "work": return "💼"
        case "exercise": return "🚶"
        case "friends": return "👥"
        case "family": return "👨‍👩‍👧‍👦"
        case "sleep": return "😴"
        case "study": return "📚"
        case "cooking": return "🍳"
        case "reading": return "📖"
        default: return "📝"
        }
    }
    
    private func generateReflectionPrompt(entries: [DiaryEntry]) -> String {
        let positiveEntries = entries.filter { $0.mood == "Positive" }
        let negativeEntries = entries.filter { $0.mood == "Negative" }
        
        // Find most common positive keywords
        var positiveKeywords: [String: Int] = [:]
        for entry in positiveEntries {
            guard let transcript = entry.transcription else { continue }
            let keywords = extractKeywords(from: transcript)
            for keyword in keywords {
                positiveKeywords[keyword.lowercased(), default: 0] += 1
            }
        }
        
        if let topPositiveKeyword = positiveKeywords.max(by: { $0.value < $1.value }) {
            return "You've mentioned '\(topPositiveKeyword.key)' \(topPositiveKeyword.value) times this week with positive feelings. What specific aspects of this are contributing to your happiness?"
        } else if negativeEntries.count > positiveEntries.count {
            return "This week has been challenging. What's one small change you could make tomorrow to improve your mood?"
        } else {
            return "What was the most meaningful moment of your week, and how can you create more experiences like it?"
        }
    }
}