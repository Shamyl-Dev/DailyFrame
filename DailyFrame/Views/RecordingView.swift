// filepath: /Users/shamylkhan/development/VsCode/Video diary/DailyFrame/DailyFrame/Views/RecordingView.swift
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
            
            VStack(spacing: 32) {
                // Header with close button
                headerView
                
                Spacer()
                
                // Date display
                VStack(spacing: 8) {
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
                
                // Recording area
                recordingArea
                
                Spacer()
                
                // Controls
                controlsView
                
                Spacer()
            }
            .padding(40)
        }
    }
    
    private var headerView: some View {
        HStack {
            Button("Close") {
                isPresented = false
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            
            Spacer()
            
            Text("DailyFrame")
                .font(.headline)
                .fontWeight(.medium)
        }
    }
    
    private var recordingArea: some View {
        ZStack {
            // Camera preview area
            RoundedRectangle(cornerRadius: 16)
                .fill(.black.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )
                .frame(width: 400, height: 300)
            
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
                .padding(16)
            } else {
                // Camera icon when not recording
                VStack(spacing: 16) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.quaternary)
                    
                    Text("Camera Preview")
                        .font(.subheadline)
                        .foregroundStyle(.quaternary)
                }
            }
        }
    }
    
    private var controlsView: some View {
        VStack(spacing: 20) {
            // Recording duration progress
            if isRecording {
                VStack(spacing: 8) {
                    ProgressView(value: recordingDuration, total: maxRecordingDuration)
                        .progressViewStyle(LinearProgressViewStyle(tint: .red))
                        .frame(width: 200)
                    
                    Text("\(Int(maxRecordingDuration - recordingDuration))s remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Record button
            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .fill(isRecording ? .red : .blue)
                        .frame(width: 80, height: 80)
                    
                    if isRecording {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .frame(width: 20, height: 20)
                    } else {
                        Circle()
                            .fill(.white)
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(isRecording ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isRecording)
            
            Text(isRecording ? "Tap to stop recording" : "Tap to start recording")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
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
        isRecording = false
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

#Preview {
    RecordingView(
        selectedDate: Date(),
        existingEntry: nil,
        isPresented: .constant(true)
    )
    .modelContainer(for: DiaryEntry.self, inMemory: true)
}