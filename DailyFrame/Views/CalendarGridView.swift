import SwiftUI
import SwiftData
import AVKit
import Combine

struct CalendarGridView: View {
    @Query private var entries: [DiaryEntry]
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var selectedEntryDate: Date?
    @Binding var showingRecordingView: Bool
    let sharedVideoRecorder: VideoRecorder
    
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
        ZStack {
            // 🔧 SOLUTION: Only show calendar when NOT in RecordingView
            if !showingRecordingView {
                // Main calendar view
                VStack(spacing: 0) {
                    // Header with month/year and navigation
                    headerView
                    
                    // Days of week
                    weekdayHeader
                    
                    // Calendar grid
                    calendarGrid
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding()
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            // RecordingView (when active)
            if showingRecordingView, let selectedDate = selectedEntryDate {
                RecordingView(
                    selectedDate: selectedDate,
                    existingEntry: entryForDate(selectedDate),
                    isPresented: $showingRecordingView,
                    videoRecorder: sharedVideoRecorder
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
                .zIndex(1)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingRecordingView)
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
                            isToday: calendar.isDateInToday(date),
                            onTap: {
                                selectedEntryDate = date
                                // 🔧 SIMPLIFIED: Always open RecordingView - it will handle video/recording logic
                                showingRecordingView = true
                            }
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
    let onTap: () -> Void

    @State private var isHovered = false
    @State private var thumbnail: NSImage?
    @State private var showLivePreview = false
    @State private var livePreviewTimer: Timer?
    @State private var player: AVPlayer?
    @State private var playerReady = false
    @State private var playerStatusCancellable: AnyCancellable?
    @State private var hideThumbnail = false

    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    // 🔧 Check if video exists for this date
    private var hasVideo: Bool {
        VideoRecorder.shared.getVideoURL(for: date) != nil
    }

    var body: some View {
        ZStack {
            // Main card background
            RoundedRectangle(cornerRadius: 12)
                .fill(dayBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(borderColor, lineWidth: isToday ? 2 : 0)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dayFormatter.string(from: date))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(dayTextColor)
                    Spacer()
                    if hasVideo {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.blue)
                    }
                }
                Spacer()
                if entry != nil {
                    Circle()
                        .fill(.blue)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(8)
            .zIndex(1)

            // --- Internal Popover Thumbnail Preview ---
            if isHovered && hasVideo {
                GeometryReader { geo in
                    let thumbWidth = geo.size.width * 0.8
                    let thumbHeight = geo.size.height * 0.55

                    VStack {
                        Spacer(minLength: geo.size.height * 0.27)
                        HStack {
                            Spacer()
                            ZStack {
                                if let thumbnail = thumbnail {
                                    Image(nsImage: thumbnail)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: thumbWidth, height: thumbHeight)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .opacity(showLivePreview && hideThumbnail ? 0 : 1)
                                        .animation(.easeInOut(duration: 0.18), value: showLivePreview && hideThumbnail)
                                }
                                if showLivePreview, let player = player {
                                    VideoPreviewPlayer(player: player)
                                        .frame(width: thumbWidth, height: thumbHeight)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .opacity(playerReady ? 1 : 0)
                                        .animation(.easeInOut(duration: 0.2), value: playerReady)
                                }
                            }
                            Spacer()
                        }
                        Spacer()
                    }
                    .background(Color.clear)
                    .transition(.opacity.combined(with: .scale))
                    .zIndex(2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 80)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            guard isCurrentMonth else { return }
            isHovered = hovering
            if hovering {
                // Get the video URL on the main actor
                Task { @MainActor in
                    let url = VideoRecorder.shared.getVideoURL(for: date)
                    if let url = url {
                        // Start timer for live preview
                        livePreviewTimer?.invalidate()
                        livePreviewTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: false) { _ in
                            Task { @MainActor in
                                let player = AVPlayer(url: url)
                                player.actionAtItemEnd = .none
                                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
                                    player.seek(to: .zero)
                                    player.play()
                                }
                                player.isMuted = true
                                self.player = player
                                self.showLivePreview = true
                                self.playerReady = false

                                // Observe when the player is ready
                                if let item = player.currentItem {
                                    playerStatusCancellable = item.publisher(for: \.status)
                                        .receive(on: DispatchQueue.main)
                                        .sink { status in
                                            if status == .readyToPlay {
                                                self.playerReady = true
                                                // Add a short delay before hiding the thumbnail
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                                    self.hideThumbnail = true
                                                }
                                            }
                                        }
                                }
                                player.play()
                            }
                        }
                        // Preload thumbnail if not already loaded
                        if thumbnail == nil {
                            DispatchQueue.global(qos: .userInitiated).async {
                                let thumb = VideoRecorder.shared.generateThumbnail(for: url)
                                DispatchQueue.main.async {
                                    self.thumbnail = thumb
                                }
                            }
                        }
                    }
                }
            } else {
                livePreviewTimer?.invalidate()
                livePreviewTimer = nil
                showLivePreview = false
                player?.pause()
                player = nil
            }
        }
        .onTapGesture {
            onTap()
        }
        .opacity(isCurrentMonth ? 1.0 : 0.3)
    }

    // Color helpers (if not already present)
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
            return .primary.opacity(0.12)
        } else {
            return .clear
        }
    }

    private var borderColor: Color {
        isToday ? .accentColor : .clear
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

import AVKit

struct VideoPreviewPlayer: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}
