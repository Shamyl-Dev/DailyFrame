import SwiftUI
import SwiftData
import AVFoundation

struct RecordingView: View {
    let selectedDate: Date
    let existingEntry: DiaryEntry?
    @Binding var isPresented: Bool
    
    @Environment(\.modelContext) private var modelContext
    @State private var isRecording = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
    
    private let maxRecordingDuration: TimeInterval = 300 // 5 minutes
    
    var body: some View {
        ZStack {
            // Background blur
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 12) { // Reduced from 16 to 12
                // Header with back button - moved much closer to top
                headerView
                
                // Date display - moved closer to header
                VStack(spacing: 4) { // Reduced from 6 to 4
                    Text(dateFormatter.string(from: selectedDate))
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    if existingEntry != nil {
                        Text("Update your entry")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Create your daily entry")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Recording area - much larger
                recordingArea
                
                // Controls - more subtle
                controlsView
                
                Spacer(minLength: 12) // Reduced from 16 to 12
            }
            .padding(.horizontal, 40)
            .padding(.top, 8) // Much reduced from 20 to 8
            .padding(.bottom, 40)
        }
        .onKeyDown { keyCode in
            if keyCode == 53 { // Escape key code
                isPresented = false
                return true
            }
            return false
        }
    }
    
    private var headerView: some View {
        HStack {
            // Back button instead of close
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
        .padding(.top, 4) // Small padding from very top
    }
    
    private var recordingArea: some View {
        ZStack {
            // Camera preview area - much larger
            RoundedRectangle(cornerRadius: 20)
                .fill(.black.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 420) // Increased minimum height since we have more space
            
            if isRecording {
                // Recording indicator
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
                        
                        Text(formatDuration(recordingDuration))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    
                    Spacer()
                }
                .padding(20)
            } else {
                // Camera icon when not recording
                VStack(spacing: 16) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.quaternary)
                    
                    Text("Camera Preview")
                        .font(.title3)
                        .foregroundStyle(.quaternary)
                }
            }
        }
    }
    
    private var controlsView: some View {
        VStack(spacing: 16) {
            // Recording duration progress
            if isRecording {
                VStack(spacing: 8) {
                    ProgressView(value: recordingDuration, total: maxRecordingDuration)
                        .progressViewStyle(LinearProgressViewStyle(tint: .red))
                        .frame(width: 240)
                    
                    Text("\(Int(maxRecordingDuration - recordingDuration))s remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            
            // Modern minimal record button
            Button(action: toggleRecording) {
                HStack(spacing: 8) {
                    // Small indicator
                    Circle()
                        .fill(isRecording ? .red : .white)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .strokeBorder(isRecording ? .clear : .secondary, lineWidth: 1)
                        )
                    
                    // Text label
                    Text(isRecording ? "Stop" : "Record")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(isRecording ? .red : .primary)
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
            .scaleEffect(isRecording ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isRecording)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            
            Text(isRecording ? "Recording in progress" : "Ready to record")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.3), value: isRecording)
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isRecording = true
        }
        recordingDuration = 0
        
        // Start timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            recordingDuration += 1
            
            // Auto-stop at max duration
            if recordingDuration >= maxRecordingDuration {
                stopRecording()
            }
        }
        
        // TODO: Implement actual video recording
        print("Starting recording for date: \(selectedDate)")
    }
    
    private func stopRecording() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isRecording = false
        }
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // TODO: Save the recording and create/update DiaryEntry
        saveEntry()
        
        print("Stopped recording. Duration: \(recordingDuration)s")
    }
    
    private func saveEntry() {
        let entry = existingEntry ?? DiaryEntry(date: selectedDate)
        entry.duration = recordingDuration
        // TODO: Set videoURL and thumbnailData when implementing actual recording
        
        if existingEntry == nil {
            modelContext.insert(entry)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save entry: \(error)")
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Extension to handle key events
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
        
        // Handle the key event with the keyCode directly
        if !onKeyDown(event.keyCode) {
            super.keyDown(with: event)
        }
    }
}

#Preview {
    RecordingView(
        selectedDate: Date(),
        existingEntry: nil,
        isPresented: .constant(true)
    )
    .modelContainer(for: DiaryEntry.self, inMemory: true)
}
