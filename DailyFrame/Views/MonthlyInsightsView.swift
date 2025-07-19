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
    @Binding var isPresented: Bool
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
    @State private var isEditingKeywords = false
    @State private var keywordRefreshID = UUID()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack {
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3) // Smaller icon
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Close")
                }
                .padding(.top, 4) // Optional: reduce vertical space

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

                if monthlyInsights.isEmpty {
                    Text("No completed months to show insights yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    let month = monthlyInsights[selectedMonthIndex]
                    let insights = month.insights
                    let monthEntries = month.entries

                    VStack(alignment: .leading, spacing: 20) {
                        // Month header
                        HStack {
                            Image(systemName: "calendar")
                                .font(.title2)
                                .foregroundStyle(.primary)
                            Text(month.monthStart.formatted(.dateTime.month().year()))
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.bottom, 4)

                        // Entries & Streaks
                        InsightCard {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                    .foregroundStyle(.green)
                                Text("Entries: \(monthEntries.count) / \(Calendar.current.range(of: .day, in: .month, for: month.monthStart)?.count ?? 0)")
                                    .font(.subheadline)
                                Spacer()
                                Image(systemName: "flame")
                                    .foregroundStyle(.orange)
                                Text("Longest streak: \(longestStreak(entries: monthEntries)) days")
                                    .font(.subheadline)
                            }
                        }

                        // Mood Distribution
                        InsightCard {
                            HStack {
                                Image(systemName: "face.smiling")
                                    .foregroundStyle(.yellow)
                                Text("Mood Distribution")
                                    .font(.subheadline)
                                Spacer()
                                MoodPieChartView(moodCounts: moodDistribution(entries: monthEntries))
                            }
                        }

                        // Most Mentioned Entities
                        let entities = AIAnalysisService.shared.extractEntities(from: monthEntries)
                        if !entities.isEmpty {
                            InsightCard {
                                HStack {
                                    Image(systemName: "person.3.sequence")
                                        .foregroundStyle(.blue)
                                    Text("Most mentioned: \(entities.joined(separator: ", "))")
                                        .font(.subheadline)
                                    Spacer()
                                }
                            }
                        }

                        // Activity Highlights
                        if !insights.activityPatterns.isEmpty {
                            InsightCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "bolt.heart")
                                            .foregroundStyle(.pink)
                                        Text("Activity Highlights")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
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

                        // Trending Keywords
                        if !insights.keywordFrequency.isEmpty {
                            InsightCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "sparkles")
                                            .foregroundStyle(.purple)
                                        Text("Trending Keywords")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Button(action: { isEditingKeywords.toggle() }) {
                                            Image(systemName: isEditingKeywords ? "checkmark.circle" : "pencil")
                                                .foregroundColor(.blue)
                                                .font(.title2)
                                                .padding(4)
                                        }
                                        .buttonStyle(.plain)
                                        .help(isEditingKeywords ? "Done" : "Edit keywords")
                                    }
                                    let sortedKeywords = insights.keywordFrequency
                                        .sorted { 
                                            if $0.value == $1.value {
                                                return $0.key < $1.key
                                            }
                                            return $0.value > $1.value
                                        }

                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 4) {
                                        ForEach(sortedKeywords.prefix(8), id: \.key) { keyword, count in
                                            HStack {
                                                Text(keyword.capitalized)
                                                    .font(.caption)
                                                Spacer()
                                                Text("(\(count))")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                if isEditingKeywords {
                                                    Button(action: {
                                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                                                            AIAnalysisService.shared.userStopwords.insert(keyword.lowercased())
                                                            keywordRefreshID = UUID()
                                                        }
                                                    }) {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .foregroundColor(.gray)
                                                            .font(.caption)
                                                    }
                                                    .buttonStyle(.plain)
                                                    .help("Remove this keyword from trending")
                                                }
                                            }
                                            .transition(.pop)
                                        }
                                    }
                                    .id(keywordRefreshID)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: keywordRefreshID)

                                    // Show removed keywords section if editing
                                    if isEditingKeywords && !AIAnalysisService.shared.userStopwords.isEmpty {
                                        Divider().padding(.vertical, 6)
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Removed Keywords")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 4) {
                                                ForEach(Array(AIAnalysisService.shared.userStopwords).sorted(), id: \.self) { word in
                                                    HStack {
                                                        Text(word.capitalized)
                                                            .font(.caption)
                                                        Spacer()
                                                        Button(action: {
                                                            withAnimation(.easeInOut(duration: 0.25)) {
                                                                var stopwords = AIAnalysisService.shared.userStopwords
                                                                stopwords.remove(word)
                                                                AIAnalysisService.shared.userStopwords = stopwords
                                                                keywordRefreshID = UUID()
                                                            }
                                                        }) {
                                                            Image(systemName: "plus.circle.fill")
                                                                .foregroundColor(.blue)
                                                                .font(.caption)
                                                        }
                                                        .buttonStyle(.plain)
                                                        .help("Restore this keyword")
                                                    }
                                                    .transition(.scale.combined(with: .opacity))
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Compare to Previous Month
                        InsightCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .foregroundStyle(.primary)
                                    Text("Compared to previous month")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                Text(compareToPreviousMonth(current: monthEntries, previous: selectedMonthIndex + 1 < monthlyInsights.count ? monthlyInsights[selectedMonthIndex + 1].entries : []))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Month in Review
                        InsightCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .foregroundStyle(.primary)
                                    Text("Month in Review")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                Text(monthSummary(entries: monthEntries))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Monthly Reflection
                        InsightCard {
                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .foregroundStyle(.primary)
                                    Text("Monthly Reflection")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                Text(monthlyReflectionPrompt(entries: monthEntries))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
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

