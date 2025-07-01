import SwiftUI
import SwiftData

struct CalendarGridView: View {
    @Query private var entries: [DiaryEntry]
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    // Consistent spacing values
    private let gridSpacing: CGFloat = 12
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 7)
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with month/year and navigation
            headerView
            
            // Days of week
            weekdayHeader
            
            // Calendar grid - Allow it to expand with flexible spacing
            calendarGrid
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }
    
    private var headerView: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text(dateFormatter.string(from: currentMonth))
                .font(.title2)
                .fontWeight(.medium)
            
            Spacer()
            
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: gridSpacing) {
            ForEach(Array(calendar.veryShortWeekdaySymbols.enumerated()), id: \.offset) { index, day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
    
    private var calendarGrid: some View {
        VStack(spacing: 0) {
            ForEach(weekRows, id: \.self) { week in
                HStack(spacing: gridSpacing) {
                    ForEach(week, id: \.self) { date in
                        DayCell(
                            date: date,
                            entry: entryForDate(date),
                            isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month),
                            isToday: calendar.isDateInToday(date)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                if week != weekRows.last {
                    Spacer(minLength: gridSpacing)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    private var weekRows: [[Date]] {
        let days = daysInMonth
        var weeks: [[Date]] = []
        
        for i in stride(from: 0, to: days.count, by: 7) {
            let endIndex = min(i + 7, days.count)
            weeks.append(Array(days[i..<endIndex]))
        }
        
        return weeks
    }
    
    private var daysInMonth: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.end) else {
            return []
        }
        
        let dateInterval = DateInterval(start: monthFirstWeek.start, end: monthLastWeek.end)
        return calendar.generateDates(inside: dateInterval, matching: DateComponents(hour: 0, minute: 0, second: 0))
    }
    
    private func entryForDate(_ date: Date) -> DiaryEntry? {
        entries.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    private func previousMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }
    
    private func nextMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }
}

struct DayCell: View {
    let date: Date
    let entry: DiaryEntry?
    let isCurrentMonth: Bool
    let isToday: Bool
    
    @State private var isHovered = false
    
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 8) {
            // Date number
            Text(dayFormatter.string(from: date))
                .font(.system(size: 14, weight: isToday ? .semibold : .medium))
                .foregroundStyle(dayTextColor)
            
            // Entry indicator or thumbnail
            if let entry = entry {
                entryPreview(for: entry)
            } else {
                emptyDayIndicator
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 80) // Minimum height for better spacing
        .background(dayBackgroundColor, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(borderColor, lineWidth: isToday ? 2 : 0)
        )
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .opacity(isCurrentMonth ? 1.0 : 0.3)
    }
    
    private var dayTextColor: Color {
        if isToday {
            return .primary
        } else if isCurrentMonth {
            return .primary
        } else {
            return .secondary
        }
    }
    
    private var dayBackgroundColor: Color {
        if isToday {
            return .accentColor.opacity(0.1)
        } else if isHovered && isCurrentMonth {
            return .primary.opacity(0.05)
        } else {
            return .clear
        }
    }
    
    private var borderColor: Color {
        isToday ? .accentColor : .clear
    }
    
    @ViewBuilder
    private func entryPreview(for entry: DiaryEntry) -> some View {
        if let thumbnailData = entry.thumbnailData,
           let image = NSImage(data: thumbnailData) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 32, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            // Video icon for entries without thumbnails
            Image(systemName: "video.fill")
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .frame(width: 32, height: 24)
                .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 4))
        }
    }
    
    private var emptyDayIndicator: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.quaternary)
            .frame(width: 32, height: 24)
            .overlay(
                Image(systemName: "plus")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            )
    }
}

extension Calendar {
    func generateDates(inside interval: DateInterval, matching components: DateComponents) -> [Date] {
        var dates: [Date] = []
        dates.append(interval.start)
        
        enumerateDates(startingAfter: interval.start, matching: components, matchingPolicy: .nextTime) { date, _, stop in
            if let date = date {
                if date < interval.end {
                    dates.append(date)
                } else {
                    stop = true
                }
            }
        }
        
        return dates
    }
}