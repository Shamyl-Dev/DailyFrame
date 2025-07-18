import SwiftUI
import SwiftData
import Charts

struct MoodPieChartView: View {
    let moodCounts: [String: Int]
    var body: some View {
        HStack(spacing: 12) {
            ForEach(moodCounts.sorted(by: { $0.key < $1.key }), id: \.key) { mood, count in
                VStack {
                    Text(mood)
                        .font(.caption2)
                    Text("\(count)")
                        .font(.headline)
                }
                .padding(8)
                .background(.quaternary.opacity(0.2))
                .cornerRadius(8)
            }
        }
    }
}

struct MonthlyInsightsView: View {
    @Query private var entries: [DiaryEntry]

    var monthlyInsights: [(monthStart: Date, entries: [DiaryEntry], insights: WeeklyInsights)] {
        let validEntries = entries.filter { 
            ($0.videoURL != nil && FileManager.default.fileExists(atPath: $0.videoURL!.path)) ||
            !($0.transcription?.isEmpty ?? true)
        }
        let months = AIAnalysisService.shared.groupEntriesByMonth(entries: validEntries)
        return months
            .compactMap { monthEntries in
                guard let monthStart = monthEntries.first?.date else { return nil }
                let idx = months.firstIndex(where: { $0.first?.date == monthStart }) ?? 0
                let previousEntries = idx + 1 < months.count ? months[idx + 1] : []
                let insights = AIAnalysisService.shared.generateWeeklyInsights(
                    entries: monthEntries,
                    previousEntries: previousEntries
                )
                return (monthStart: monthStart, entries: monthEntries, insights: insights)
            }
    }

    @State private var selectedMonthIndex: Int = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Month picker
                if monthlyInsights.count > 1 {
                    Picker("Select Month", selection: $selectedMonthIndex) {
                        ForEach(monthlyInsights.indices, id: \.self) { idx in
                            let monthStart = monthlyInsights[idx].monthStart
                            Text(monthStart.formatted(.dateTime.month().year()))
                                .tag(idx)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(.bottom, 8)
                }

                // Show insights for selected month
                if monthlyInsights.isEmpty {
                    Text("No completed months to show insights yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    let month = monthlyInsights[selectedMonthIndex]
                    let insights = month.insights
                    let monthEntries = month.entries

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Month of \(month.monthStart.formatted(.dateTime.month().year()))")
                            .font(.headline)

                        // 1. Streaks & Consistency
                        let streak = longestStreak(entries: monthEntries)
                        let daysRecorded = monthEntries.count
                        let totalDays = Calendar.current.range(of: .day, in: .month, for: month.monthStart)?.count ?? 0
                        Text("Entries this month: \(daysRecorded) / \(totalDays) • Longest streak: \(streak) days")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // 2. Mood Distribution Pie Chart
                        MoodPieChartView(moodCounts: moodDistribution(entries: monthEntries))

                        // 3. Most Mentioned People/Places
                        let entities = AIAnalysisService.shared.extractEntities(from: monthEntries)
                        if !entities.isEmpty {
                            Text("Most mentioned: \(entities.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // 4. Top Activities & Trends
                        if !insights.activityPatterns.isEmpty {
                            InsightCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Activity Highlights")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    ForEach(insights.activityPatterns.prefix(5), id: \.keyword) { pattern in
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

                        // 5. Trending Keywords
                        if !insights.keywordFrequency.isEmpty {
                            InsightCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Trending Keywords")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    let sortedKeywords = insights.keywordFrequency.sorted { $0.value > $1.value }
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 4) {
                                        ForEach(sortedKeywords.prefix(8), id: \.key) { keyword, count in
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

                        // 6. Compare to Previous Month
                        InsightCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Compared to previous month")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(compareToPreviousMonth(current: monthEntries, previous: selectedMonthIndex + 1 < monthlyInsights.count ? monthlyInsights[selectedMonthIndex + 1].entries : []))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // 7. Month in Review Summary
                        InsightCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Month in Review")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(monthSummary(entries: monthEntries))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // 8. Monthly Reflection Prompt
                        InsightCard {
                            VStack(alignment: .leading) {
                                Text("Monthly Reflection")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(monthlyReflectionPrompt(entries: monthEntries))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                }
            }
            .padding()
        }
        .onAppear {
            selectedMonthIndex = 0
        }
    }

    // --- Helper Methods ---

    // Streak calculation
    private func longestStreak(entries: [DiaryEntry]) -> Int {
        let sorted = entries.sorted { $0.date < $1.date }
        var streak = 0, maxStreak = 0
        var prevDate: Date?
        let calendar = Calendar.current
        for entry in sorted {
            if let prev = prevDate, calendar.isDate(entry.date, equalTo: calendar.date(byAdding: .day, value: 1, to: prev)!, toGranularity: .day) {
                streak += 1
            } else {
                streak = 1
            }
            maxStreak = max(maxStreak, streak)
            prevDate = entry.date
        }
        return maxStreak
    }

    // Mood distribution for pie chart
    private func moodDistribution(entries: [DiaryEntry]) -> [String: Int] {
        var counts: [String: Int] = ["Positive": 0, "Neutral": 0, "Negative": 0]
        for entry in entries {
            if let mood = entry.mood {
                counts[mood, default: 0] += 1
            }
        }
        return counts
    }

    // Compare to previous month
    private func compareToPreviousMonth(current: [DiaryEntry], previous: [DiaryEntry]) -> String {
        guard !previous.isEmpty else { return "No previous month data." }
        let currentPos = current.filter { $0.mood == "Positive" }.count
        let prevPos = previous.filter { $0.mood == "Positive" }.count
        let diff = currentPos - prevPos
        if diff > 0 {
            return "You had \(diff) more positive days than last month."
        } else if diff < 0 {
            return "You had \(-diff) fewer positive days than last month."
        } else {
            return "Your number of positive days was the same as last month."
        }
    }

    // Month summary (simple version)
    private func monthSummary(entries: [DiaryEntry]) -> String {
        let keywords = entries.flatMap { AIAnalysisService.shared.extractKeywords(from: $0.transcription ?? "") }
        let topKeywords = Dictionary(grouping: keywords, by: { $0 }).mapValues { $0.count }
        let sorted = topKeywords.sorted { $0.value > $1.value }.prefix(3).map { "\($0.key)" }
        return "This month, you talked most about: \(sorted.joined(separator: ", "))."
    }

    // Monthly reflection prompt (simple version)
    private func monthlyReflectionPrompt(entries: [DiaryEntry]) -> String {
        let positives = entries.filter { $0.mood == "Positive" }.count
        let negatives = entries.filter { $0.mood == "Negative" }.count
        if positives > negatives {
            return "What made this month feel good? How can you keep the momentum going?"
        } else if negatives > positives {
            return "What challenged you most this month? What could help next month feel better?"
        } else {
            return "What was the most meaningful moment of your month?"
        }
    }

    private func trendText(_ direction: TrendDirection) -> String {
        switch direction {
        case .up: return "upward"
        case .down: return "downward"
        case .stable: return "stable"
        }
    }
}

