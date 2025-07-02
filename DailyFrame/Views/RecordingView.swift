import SwiftUI
import SwiftData
import AVFoundation

struct RecordingView: View {
    let selectedDate: Date
    let existingEntry: DiaryEntry?
    @Binding var isPresented: Bool
    
    @Environment(\.modelContext) private var modelContext
    @StateObject private var videoRecorder = VideoRecorder()
    
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
            
            VStack(spacing: 12) {
                // Header with back button
                headerView
                
                // Date display
                VStack(spacing: 4) {
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
                
                // Recording area with real camera preview
                recordingArea
                
                // Controls
                controlsView
                
                Spacer(minLength: 12)
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .onAppear {
            videoRecorder.startSession()
        }
        .onDisappear {
            videoRecorder.stopSession()
        }
        .onKeyDown { keyCode in
            if keyCode == 53 { // Escape key code
                isPresented = false
                return true
            }
            return false
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
        .padding(.top, 4)
    }
    
    private var recordingArea: some View {
        ZStack {
            // Camera preview background
            RoundedRectangle(cornerRadius: 20)
                .fill(.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 420)
            
            // Real camera preview or placeholder
            if videoRecorder.hasPermission, let previewLayer = videoRecorder.previewLayer {
                CameraPreviewView(previewLayer: previewLayer)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            } else {
                // Placeholder when no camera access
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
            
            // Recording indicator overlay
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
    
    private var controlsView: some View {
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
            
            // Show Videos Button
            if !videoRecorder.isRecording {
                Button(action: {
                    videoRecorder.showVideosInFinder()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                        Text("Show Videos")
                            .font(.caption)
                    }
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
            
            Text(videoRecorder.isRecording ? "Recording in progress" : (videoRecorder.hasPermission ? "Ready to record" : "Grant permissions to continue"))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.3), value: videoRecorder.isRecording)
    }
    
    private func toggleRecording() {
        Task {
            if videoRecorder.isRecording {
                if let videoURL = await videoRecorder.stopRecording() {
                    await saveEntry(videoURL: videoURL)
                }
            } else {
                let _ = await videoRecorder.startRecording(for: selectedDate)
            }
        }
    }
    
    private func saveEntry(videoURL: URL) async {
        let entry = existingEntry ?? DiaryEntry(date: selectedDate)
        entry.duration = videoRecorder.recordingDuration
        entry.videoURL = videoURL
        
        if existingEntry == nil {
            modelContext.insert(entry)
        }
        
        do {
            try modelContext.save()
        } catch {
            videoRecorder.errorMessage = "Failed to save video entry"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Keep the existing key handling extensions...
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
        isPresented: .constant(true)
    )
    .modelContainer(for: DiaryEntry.self, inMemory: true)
}
