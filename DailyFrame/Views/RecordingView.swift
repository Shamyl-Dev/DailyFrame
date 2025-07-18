import SwiftUI
import SwiftData
import AVFoundation
import AVKit

// 🔧 UPDATED: Add Equatable conformance
enum RecordingViewState: Equatable {
    case initializing
    case recording
    case playback(URL)
    
    // 🔧 NEW: Implement Equatable manually since URL needs special handling
    static func == (lhs: RecordingViewState, rhs: RecordingViewState) -> Bool {
        switch (lhs, rhs) {
        case (.initializing, .initializing):
            return true
        case (.recording, .recording):
            return true
        case (.playback(let lhsURL), .playback(let rhsURL)):
            return lhsURL == rhsURL
        default:
            return false
        }
    }
}

struct RecordingView: View {
    let selectedDate: Date
    let existingEntry: DiaryEntry?
    @Binding var isPresented: Bool
    let videoRecorder: VideoRecorder
    
    @Environment(\.modelContext) private var modelContext
    @State private var currentState: RecordingViewState = .initializing
    @State private var player: AVPlayer?
    @State private var showingReRecordConfirmation = false
    @StateObject private var transcriptionService = TranscriptionService()
    @State private var isTranscribing = false
    @State private var transcriptError: String?
    @State private var transcriptionTask: Task<Void, Never>?
    @State private var showTranscriptSection = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
    
    private let maxRecordingDuration: TimeInterval = 300 // 5 minutes
    
    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header always visible
                headerView
                Divider() // 👈 Divider below header

                // Scrollable main content
                ScrollView {
                    VStack(spacing: 12) {
                        // Date display (stays consistent)
                        VStack(spacing: 4) {
                            Text(dateFormatter.string(from: selectedDate))
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            Text(stateSubtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 12) // 👈 Add or increase this value for more space below the divider

                        // Main content area (swaps based on state)
                        mainContentArea

                        // Controls (adapts based on state)
                        controlsView

                        // 👇 Transcript section goes here!
                        if showTranscriptSection, case .playback = currentState {
                            transcriptSection
                                .transition(.opacity.combined(with: .scale(scale: 0.85)))
                        }

                        Spacer(minLength: 12)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            initializeView()
            // Fade in transcript section after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.easeInOut(duration: 0.5)) { // 👈 Slower, more apparent
                    showTranscriptSection = true
                }
            }
        }
        .onDisappear {
            cleanupView()
            removeOrphanedDiaryEntries(context: modelContext)
        }
        .onKeyDown { keyCode in
            if keyCode == 53 { isPresented = false; return true }
            return false
        }
        .alert("Re-record Video", isPresented: $showingReRecordConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Re-record", role: .destructive) {
                reRecordVideo()
            }
        } message: {
            Text("Are you sure you want to delete this video and record a new one? This action cannot be undone.")
        }
        .alert("Permission Required", isPresented: .constant(videoRecorder.errorMessage != nil && !videoRecorder.hasPermission)) {
            Button("Retry") {
                videoRecorder.refreshPermissions()
            }
            Button("Cancel") {
                isPresented = false
            }
        } message: {
            Text(videoRecorder.errorMessage ?? "Camera and microphone access is required.")
        }
    }
    
    // MARK: - State-dependent properties
    
    private var stateSubtitle: String {
        switch currentState {
        case .initializing:
            return existingEntry != nil ? "Update your entry" : "Create your daily entry"
        case .recording:
            return "Recording your daily entry"
        case .playback:
            return "Your daily entry"
        }
    }
    
    // MARK: - Views
    
    private var headerView: some View {
        HStack {
            Button(action: {
                isPresented = false
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                    Text("Back")
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text("DailyFrame")
                .font(.headline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)   // Add bottom padding for better vertical centering
    }
    
    private var mainContentArea: some View {
        ZStack {
            // 🔧 SOLUTION: Semi-transparent background that works with parent blur
            RoundedRectangle(cornerRadius: 20)
                .fill(.black.opacity(0.85)) // Semi-transparent to let blur show through edges
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.quaternary.opacity(0.3), lineWidth: 1)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity) // 👈 Remove minHeight constraint
            
            // Content based on current state
            Group {
                switch currentState {
                case .initializing:
                    initializingContent
                case .recording:
                    recordingContent
                case .playback(let videoURL):
                    playbackContent(videoURL: videoURL)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
        .frame(minHeight: 400, maxHeight: .infinity) // 👈 Move frame constraint here with higher minHeight
        .compositingGroup() // Keep this to isolate video rendering
    }
    
    private var initializingContent: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
                .tint(.white)
            
            Text("Initializing camera...")
                .foregroundStyle(.white)
                .font(.subheadline)
        }
    }
    
    private var recordingContent: some View {
        ZStack {
            if videoRecorder.hasPermission, let previewLayer = videoRecorder.previewLayer {
                CameraPreviewView(previewLayer: previewLayer)
                    .background(Color.black)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                cameraPlaceholder
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Recording indicator overlay (unchanged)
            if videoRecorder.isRecording {
                VStack {
                    HStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("REC")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                        Spacer()
                        Text(formatDuration(videoRecorder.recordingDuration))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                    }
                    .padding(12)
                    .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                    Spacer()
                }
                .padding(20)
            }
        }
    }
    
    private func playbackContent(videoURL: URL) -> some View {
        Group {
            if let player = player {
                VideoPlayer(player: player)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // 👈 Add this line
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                        .tint(.white)
                    Text("Loading video...")
                        .foregroundStyle(.white)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity) // 👈 Add this line
            }
        }
        .onAppear {
            if let entry = existingEntry, let transcript = entry.transcription {
                transcriptionService.transcript = transcript
            }
            triggerTranscriptionIfNeeded(for: videoURL)
        }
    }

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcript")
                .font(.headline)
                .padding(.bottom, 2)
            if isTranscribing {
                HStack {
                    ProgressView()
                    Text("Transcribing...")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)
            } else if let error = transcriptError,
                      error.localizedCaseInsensitiveContains("no speech detected") ||
                      error.localizedCaseInsensitiveContains("no audio track found") {
                Text("No words detected in this video.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            } else if let error = transcriptError {
                Text("Transcription failed: \(error)")
                    .foregroundStyle(.red)
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            } else if !transcriptionService.transcript.isEmpty {
                Text(transcriptionService.transcript)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .padding(8)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                
                // 👇 Add sentiment score display here
                let sentiment = AIAnalysisService.shared.analyzeSentiment(text: transcriptionService.transcript)
                HStack(spacing: 8) {
                    Text("Sentiment Score: \(String(format: "%.2f", sentiment.score))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("(\(sentiment.label))")
                        .font(.caption2)
                        .foregroundStyle(
                            sentiment.label == "Positive" ? .green :
                            sentiment.label == "Negative" ? .red :
                            .yellow
                        )
                }
                .padding(.leading, 4)
            }
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cameraPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: videoRecorder.hasPermission ? "video.fill" : "video.slash.fill")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            
            Text(videoRecorder.hasPermission ? "Camera Preview" : "Camera Access Required")
                .font(.title3)
                .foregroundStyle(.quaternary)
            
            if !videoRecorder.hasPermission {
                VStack(spacing: 8) {
                    Text("Grant camera and microphone permissions to record videos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Refresh Permissions") {
                        videoRecorder.refreshPermissions()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                    .font(.caption)
                }
            }
        }
    }
    
    private var controlsView: some View {
        VStack(spacing: 16) {
            // State-specific controls
            switch currentState {
            case .initializing:
                EmptyView()
                
            case .recording:
                recordingControls
                
            case .playback:
                playbackControls
            }
            
            // Common controls
            commonControls
        }
        .animation(.easeInOut(duration: 0.3), value: currentState)
    }
    
    private var recordingControls: some View {
        VStack(spacing: 16) {
            // Recording duration progress
            if videoRecorder.isRecording {
                VStack(spacing: 8) {
                    ProgressView(value: videoRecorder.recordingDuration, total: maxRecordingDuration)
                        .progressViewStyle(LinearProgressViewStyle(tint: .red))
                        .frame(width: 240)
                    
                    Text("\(Int(maxRecordingDuration - videoRecorder.recordingDuration))s remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            
            // Record button
            Button(action: toggleRecording) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(videoRecorder.isRecording ? .red : .white)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .strokeBorder(videoRecorder.isRecording ? .clear : .secondary, lineWidth: 1)
                        )
                    
                    Text(videoRecorder.isRecording ? "Stop" : "Record")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(videoRecorder.isRecording ? .red : .primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(.quaternary, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(!videoRecorder.hasPermission)
            .scaleEffect(videoRecorder.isRecording ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: videoRecorder.isRecording)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
    
    private var playbackControls: some View {
        VStack(spacing: 16) {
            // Re-record button
            Button(action: {
                showingReRecordConfirmation = true
            }) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 8, height: 8)
                    
                    Text("Re-record")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(.quaternary, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
    
    private var commonControls: some View {
        EmptyView()
    }
    
    private var statusText: String {
        switch currentState {
        case .initializing:
            return "Setting up camera..."
        case .recording:
            return videoRecorder.isRecording ? "Recording in progress" : (videoRecorder.hasPermission ? "Ready to record" : "Grant permissions to continue")
        case .playback:
            return "Tap to play, pause, or seek"
        }
    }
    
    // MARK: - State Management
    
    // 🔧 OPTIMIZED: State transitions with session guards
    private func initializeView() {
        print("📹 RecordingView appeared - checking for existing video")
        
        // Check if video already exists for this date
        if let videoURL = videoRecorder.getVideoURL(for: selectedDate) {
            // Video exists, go directly to playback
            transitionToPlayback(videoURL: videoURL)
        } else {
            // No video, start camera initialization only if needed
            currentState = .initializing
            
            Task {
                // 🔧 OPTIMIZED: Only initialize if not already configured
                if !videoRecorder.isSessionActive {
                    await videoRecorder.initializeCamera()
                    await videoRecorder.startSession()
                }
                
                // 🔧 OPTIMIZED: Reduced delay and animation duration
                try? await Task.sleep(for: .milliseconds(100))
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        currentState = .recording
                    }
                }
            }
        }
    }
    
    // 🔧 OPTIMIZED: Proper cleanup with memory management
    private func cleanupView() {
        print("📹 RecordingView disappeared - cleaning up resources")
        if let existingPlayer = player {
            existingPlayer.pause()
            existingPlayer.replaceCurrentItem(with: nil)
            player = nil
        }
        NotificationCenter.default.removeObserver(self)
        Task {
            await videoRecorder.stopSession()
        }
        transcriptionService.cancelRecognition()
        transcriptionTask?.cancel()
        transcriptionTask = nil
    }
    
    // 🔧 OPTIMIZED: Improved playback transition with proper cleanup
    private func transitionToPlayback(videoURL: URL) {
        // Clean up existing player first
        if let existingPlayer = player {
            existingPlayer.pause()
            existingPlayer.replaceCurrentItem(with: nil)
            player = nil
        }

        withAnimation(.easeInOut(duration: 0.15)) {
            currentState = .playback(videoURL)
        }

        // Delay playback until animation finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
            Task {
                let newPlayer = AVPlayer(url: videoURL)
                await MainActor.run {
                    self.player = newPlayer
                    newPlayer.play()
                }
                await videoRecorder.stopSession()
            }
        }
    }
    
    private func reRecordVideo() {
        // Delete existing video file
        if case .playback(let videoURL) = currentState {
            try? FileManager.default.removeItem(at: videoURL)
        }

        // Delete DiaryEntry if no new video will be recorded
        if let entry = existingEntry {
            // Only delete if transcript is empty and no video is present
            if (entry.transcription?.isEmpty ?? true) && entry.videoURL == nil {
                modelContext.delete(entry)
                try? modelContext.save()
            } else {
                // Otherwise, just clear transcript and mood
                entry.transcription = nil
                entry.mood = nil
                try? modelContext.save()
            }
        }

        // Clean up player
        player?.pause()
        player = nil

        // Clear transcript and error
        transcriptionService.transcript = ""
        transcriptError = nil

        // Transition back to recording mode
        withAnimation(.easeInOut(duration: 0.3)) {
            currentState = .initializing
        }

        // Reinitialize camera
        Task {
            await videoRecorder.initializeCamera()
            await videoRecorder.startSession()
            try? await Task.sleep(for: .milliseconds(200))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentState = .recording
                }
            }
        }
    }
    
    // MARK: - Recording Logic
    
    private func toggleRecording() {
        Task {
            if videoRecorder.isRecording {
                if let videoURL = await videoRecorder.stopRecording() {
                    await saveEntry(videoURL: videoURL)
                    triggerTranscriptionIfNeeded(for: videoURL, force: true)
                    await MainActor.run {
                        transitionToPlayback(videoURL: videoURL)
                    }
                }
            } else {
                let _ = await videoRecorder.startRecording(for: selectedDate)
            }
        }
    }
    
    private func saveEntry(videoURL: URL) async {
        // Find any existing entry for this date
        let entry = existingEntry ?? findEntry(for: selectedDate) ?? DiaryEntry(date: selectedDate)
        entry.duration = videoRecorder.recordingDuration
        entry.videoURL = videoURL

        if entry.id == nil { // Only insert if truly new
            modelContext.insert(entry)
        }

        do {
            try modelContext.save()
        } catch {
            videoRecorder.errorMessage = "Failed to save video entry"
        }
    }
    
    // Helper to find entry for date (add to RecordingView)
    private func findEntry(for date: Date) -> DiaryEntry? {
        // Use modelContext to fetch entries for the date
        let request = FetchDescriptor<DiaryEntry>()
        if let entries = try? modelContext.fetch(request) {
            return entries.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
        }
        return nil
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func triggerTranscriptionIfNeeded(for videoURL: URL, force: Bool = false) {
        let entry = existingEntry ?? DiaryEntry(date: selectedDate)
        guard force || (entry.transcription?.isEmpty ?? true), !isTranscribing else {
            transcriptionService.transcript = entry.transcription ?? ""
            return
        }
        isTranscribing = true
        transcriptError = nil
        transcriptionTask?.cancel() // Cancel any previous task
        transcriptionTask = Task {
            do {
                let text = try await transcriptionService.transcribeVideo(url: videoURL)
                await MainActor.run {
                    // Only update if still transcribing
                    if isTranscribing {
                        transcriptionService.transcript = text
                        entry.transcription = text
                        try? modelContext.save()

                        // Analyze mood and save
                        let moodResult = AIAnalysisService.shared.analyzeSentiment(text: text)
                        entry.mood = moodResult.label

                        print("Sentiment score: \(moodResult.score), label: \(moodResult.label)")

                        if existingEntry == nil {
                            modelContext.insert(entry)
                        }
                        try? modelContext.save()
                        isTranscribing = false
                    }
                }
            } catch {
                await MainActor.run {
                    if isTranscribing {
                        transcriptError = error.localizedDescription
                        isTranscribing = false
                    }
                }
            }
        }
    }
}

// Keep existing extensions...
extension View {
    func onKeyDown(perform action: @escaping (UInt16) -> Bool) -> some View {
        self.background(KeyEventHandlingView(onKeyDown: action))
    }
}

struct KeyEventHandlingView: NSViewRepresentable {
    let onKeyDown: (UInt16) -> Bool
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyHandlingNSView()
        view.onKeyDown = onKeyDown
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let keyView = nsView as? KeyHandlingNSView {
            keyView.onKeyDown = onKeyDown
        }
    }
}

class KeyHandlingNSView: NSView {
    var onKeyDown: ((UInt16) -> Bool)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
    
    override func keyDown(with event: NSEvent) {
        guard let onKeyDown = onKeyDown else {
            super.keyDown(with: event)
            return
        }
        
        if !onKeyDown(event.keyCode) {
            super.keyDown(with: event)
        }
    }
}

#Preview {
    RecordingView(
        selectedDate: Date(),
        existingEntry: nil,
        isPresented: .constant(true),
        videoRecorder: VideoRecorder.shared
    )
    .modelContainer(for: DiaryEntry.self, inMemory: true)
}
