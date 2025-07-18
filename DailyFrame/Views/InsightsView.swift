import SwiftUI
import SwiftData

struct InsightsView: View {
    @Query private var entries: [DiaryEntry]

    // Compute weekly insights
    var weeklyInsights: [(weekStart: Date, insights: WeeklyInsights)] {
        let validEntries = entries.filter { 
            ($0.videoURL != nil && FileManager.default.fileExists(atPath: $0.videoURL!.path)) ||
            !($0.transcription?.isEmpty ?? true)
        }
        print("STEP 1: Valid entry dates:")
        for entry in validEntries {
            print(" - \(entry.date)")
        }

        let weeks = AIAnalysisService.shared.groupEntriesByWeek(entries: validEntries)
        print("STEP 2: Week groups (raw):")
        for (i, weekEntries) in weeks.enumerated() {
            print("  Week \(i):")
            for entry in weekEntries {
                print("    - \(entry.date)")
            }
        }

        let calendar = Calendar.current
        let now = Date()
        return weeks
            .map { weekEntries in
                let filtered = weekEntries.filter { entry in
                    let hasVideo = entry.videoURL != nil && FileManager.default.fileExists(atPath: entry.videoURL!.path)
                    let hasTranscript = !(entry.transcription?.isEmpty ?? true)
                    let result = hasVideo || hasTranscript
                    print("STEP 3: Filtering entry \(entry.date): hasVideo=\(hasVideo), hasTranscript=\(hasTranscript), included=\(result)")
                    return result
                }
                print("STEP 4: Week after filtering:")
                for entry in filtered {
                    print("    - \(entry.date)")
                }
                return filtered
            }
            .filter { !$0.isEmpty }
            .enumerated()
            .compactMap { (idx, weekEntries) in
                guard let weekStart = weekEntries.first?.date else { return nil }
                let weekInterval = calendar.dateInterval(of: .weekOfYear, for: weekStart)
                let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekInterval?.start ?? weekStart)!
                print("STEP 5: Week group: \(weekStart) to \(weekEnd), now: \(now), entries: \(weekEntries.count)")
                if weekEnd < now {
                    print("STEP 6: Including week: \(weekStart) to \(weekEnd)")
                } else {
                    print("STEP 6: Skipping incomplete week: \(weekStart) to \(weekEnd)")
                    return nil
                }
                // Get previous week entries (if any)
                let previousEntries = idx + 1 < weeks.count ? weeks[idx + 1].filter { entry in
                    let hasVideo = entry.videoURL != nil && FileManager.default.fileExists(atPath: entry.videoURL!.path)
                    let hasTranscript = !(entry.transcription?.isEmpty ?? true)
                    return hasVideo || hasTranscript
                } : []
                let insights = AIAnalysisService.shared.generateWeeklyInsights(
                    entries: weekEntries,
                    previousEntries: previousEntries
                )

                return (weekStart: weekInterval?.start ?? weekStart, insights: insights)
            }
    }

    @State private var selectedWeekIndex: Int = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Dropdown for week selection
                if weeklyInsights.count > 1 {
                    Picker("Select Week", selection: $selectedWeekIndex) {
                        ForEach(weeklyInsights.indices, id: \.self) { idx in
                            let weekStart = weeklyInsights[idx].weekStart
                            let weekEnd = Calendar.current.date(byAdding: .day, value: 6, to: weekStart)!
                            Text("\(weekStart.formatted(date: .abbreviated, time: .omitted)) - \(weekEnd.formatted(date: .abbreviated, time: .omitted))")
                                .tag(idx)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(.bottom, 8)
                }

                // Show insights for selected week
                if weeklyInsights.isEmpty {
                    Text("No completed weeks to show insights yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    let week = weeklyInsights[selectedWeekIndex]
                    let insights = week.insights

                    VStack(alignment: .leading, spacing: 20) {
                        // Week header
                        HStack {
                            Image(systemName: "calendar")
                                .font(.title2)
                                .foregroundStyle(.primary)
                            Text("Week of \(week.weekStart.formatted(date: .abbreviated, time: .omitted))")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.bottom, 4)

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
                                    HStack {
                                        Image(systemName: "sparkles")
                                            .foregroundStyle(.purple)
                                        Text("Trending Keywords")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
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
                    }
                    .padding()
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .onAppear {
            let calendar = Calendar.current
            let now = Date()
            if let idx = weeklyInsights.firstIndex(where: { calendar.isDate($0.weekStart, equalTo: now, toGranularity: .weekOfYear) }) {
                selectedWeekIndex = idx
            } else {
                selectedWeekIndex = 0 // fallback
            }
        }
        .onChange(of: weeklyInsights.count) { oldValue, newValue in
            selectedWeekIndex = 0
        }
        .onChange(of: selectedWeekIndex) { oldValue, newValue in
            // If you need to react to the change, do it here
        }
        .onChange(of: entries) { oldValue, newValue in
            // Re-select the current week if it exists, otherwise fallback to 0
            let calendar = Calendar.current
            let now = Date()
            if let idx = weeklyInsights.firstIndex(where: { calendar.isDate($0.weekStart, equalTo: now, toGranularity: .weekOfYear) }) {
                selectedWeekIndex = idx
            } else {
                selectedWeekIndex = 0
            }
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