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
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var totalScore = 0.0
        var count = 0

        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range])
            let tagger = NLTagger(tagSchemes: [.sentimentScore])
            tagger.string = sentence
            let (sentiment, _) = tagger.tag(at: sentence.startIndex, unit: .paragraph, scheme: .sentimentScore)
            let score = Double(sentiment?.rawValue ?? "0") ?? 0.0
            totalScore += score
            count += 1
            return true
        }

        let avgScore = count > 0 ? totalScore / Double(count) : 0.0

        let label: String
        if avgScore > -0.60 {
            label = "Positive"
        } else if avgScore < -0.80 {
            label = "Negative"
        } else {
            label = "Neutral"
        }
        return (avgScore, label)
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
        tagger.setLanguage(.english, range: transcript.startIndex..<transcript.endIndex)

        var keywords: [String] = []
        tagger.enumerateTags(in: transcript.startIndex..<transcript.endIndex,
                            unit: .word,
                            scheme: .lexicalClass) { tag, tokenRange in
            let word = String(transcript[tokenRange])

            if tag == .noun || tag == .verb {
                if word.count > 3 {
                    keywords.append(word)
                }
            }
            return true
        }
        return keywords
    }
    
    func extractEntities(from entries: [DiaryEntry]) -> [String] {
        var entities: [String: Int] = [:]
        for entry in entries {
            guard let transcript = entry.transcription else { continue }
            let tagger = NLTagger(tagSchemes: [.nameType])
            tagger.string = transcript
            tagger.setLanguage(.english, range: transcript.startIndex..<transcript.endIndex)
            tagger.enumerateTags(in: transcript.startIndex..<transcript.endIndex, unit: .word, scheme: .nameType) { tag, tokenRange in
                if let tag = tag, tag == .personalName || tag == .placeName || tag == .organizationName {
                    let entity = String(transcript[tokenRange])
                    entities[entity, default: 0] += 1
                }
                return true
            }
        }
        // Return top 3 entities by frequency
        return Array(entities.sorted { $0.value > $1.value }.prefix(3).map { $0.key })
    }
    
    func generateWeeklyInsights(entries: [DiaryEntry], previousEntries: [DiaryEntry]) -> WeeklyInsights {
        return WeeklyInsights(
            moodTrend: analyzeMoodTrend(current: entries, previous: previousEntries),
            keywordFrequency: analyzeKeywordFrequency(entries: entries),
            activityPatterns: analyzeActivityPatterns(entries: entries),
            reflectionPrompt: generateReflectionPrompt(entries: entries)
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
        let currentTotal = current.count
        let previousTotal = previous.count

        // If either week has no entries, don't show a trend
        if currentTotal == 0 || previousTotal == 0 {
            return MoodTrend(direction: .stable, percentage: 0, emoji: "🟡")
        }

        let currentPositive = current.filter { $0.mood == "Positive" }.count
        let currentRatio = Double(currentPositive) / Double(currentTotal)

        let previousPositive = previous.filter { $0.mood == "Positive" }.count
        let previousRatio = Double(previousPositive) / Double(previousTotal)

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
        let stopwords: Set<String> = [
            "the", "and", "for", "with", "that", "this", "from", "have", "has", "was", "were", "are", "but", "not", "you", "your", "they", "them", "their", "it's", "i'm", "i've", "we", "us", "our", "me", "my", "mine", "a", "an", "of", "to", "in", "on", "at", "by", "as", "is", "it", "be", "so", "do", "did", "can", "could", "would", "should", "will", "just", "about", "more", "some", "any", "all", "no", "yes", "if", "or", "than", "then", "when", "where", "who", "what", "which", "how", "why", "because", "bunch", "stuff", "words", "month", "seconds", "couple"
        ]
        var keywordCounts: [String: Int] = [:]
        for entry in entries {
            guard let transcript = entry.transcription else { continue }
            let keywords = extractKeywords(from: transcript)
            for keyword in keywords {
                let lowercased = keyword.lowercased()
                if lowercased.count > 2 && !stopwords.contains(lowercased) {
                    keywordCounts[lowercased, default: 0] += 1
                }
            }
        }
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
    
    func groupEntriesByWeek(entries: [DiaryEntry]) -> [[DiaryEntry]] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.dateInterval(of: .weekOfYear, for: entry.date)?.start ?? entry.date
        }
        // Sort weeks by date descending (most recent first)
        return grouped
            .sorted { $0.key > $1.key } // Make sure this is present!
            .map { $0.value.sorted { $0.date < $1.date } }
    }
    
    func groupEntriesByMonth(entries: [DiaryEntry]) -> [[DiaryEntry]] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.dateInterval(of: .month, for: entry.date)?.start ?? entry.date
        }
        // Sort months by date descending (most recent first)
        return grouped
            .sorted { $0.key > $1.key }
            .map { $0.value.sorted { $0.date < $1.date } }
    }
}