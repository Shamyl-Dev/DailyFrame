import SwiftUI
import SwiftData

struct InsightsView: View {
    @Query private var entries: [DiaryEntry]
    @State private var insights: WeeklyInsights?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Text("This Week's Insights")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("Last 7 days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let insights = insights {
                    // Mood Trend
                    InsightCard {
                        HStack {
                            Text(insights.moodTrend.emoji)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Mood trending \(trendText(insights.moodTrend.direction))")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if insights.moodTrend.percentage > 0 {
                                    Text("(\(insights.moodTrend.direction == .up ? "+" : "-")\(insights.moodTrend.percentage)%)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }
                    
                    // Activity Patterns
                    if !insights.activityPatterns.isEmpty {
                        InsightCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Activity Highlights")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                ForEach(insights.activityPatterns.prefix(3), id: \.keyword) { pattern in
                                    HStack {
                                        Text(pattern.emoji)
                                        Text("\(pattern.keyword.capitalized) mentioned \(pattern.frequency) times")
                                            .font(.caption)
                                        if pattern.sentiment == "positive" {
                                            Text("(keeps you happy!)")
                                                .font(.caption)
                                                .foregroundStyle(.green)
                                        }
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                    
                    // Reflection Prompt
                    InsightCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("💭")
                                    .font(.title3)
                                Text("Reflection Prompt")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            Text(insights.reflectionPrompt)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 30)
                        }
                    }
                    
                    // Trending Keywords
                    if !insights.keywordFrequency.isEmpty {
                        InsightCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Trending Keywords")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                let sortedKeywords = insights.keywordFrequency.sorted { $0.value > $1.value }
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 4) {
                                    ForEach(sortedKeywords.prefix(6), id: \.key) { keyword, count in
                                        HStack {
                                            Text(keyword.capitalized)
                                                .font(.caption)
                                            Spacer()
                                            Text("(\(count))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Loading state
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Analyzing your week...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding()
        }
        .onAppear {
            generateInsights()
        }
    }
    
    private func generateInsights() {
        insights = AIAnalysisService.shared.generateWeeklyInsights(entries: entries)
    }
    
    private func trendText(_ direction: TrendDirection) -> String {
        switch direction {
        case .up: return "upward"
        case .down: return "downward"
        case .stable: return "stable"
        }
    }
}

struct InsightCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.quaternary.opacity(0.5), lineWidth: 0.5)
            )
    }
}

#Preview {
    InsightsView()
        .modelContainer(for: DiaryEntry.self, inMemory: true)
}