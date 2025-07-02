//
//  ContentView.swift
//  DailyFrame
//
//  Created by Shamyl Khan on 7/1/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingRecordingView = false
    // 🔧 CHANGED: Use singleton instead of @StateObject
    @ObservedObject private var sharedVideoRecorder = VideoRecorder.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background with subtle blur
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .ignoresSafeArea(.all)
                
                VStack(spacing: 0) {
                    // App title - smoother transition
                    headerView
                        .opacity(showingRecordingView ? 0 : 1)
                        .scaleEffect(showingRecordingView ? 0.95 : 1.0, anchor: .top)
                        .offset(y: showingRecordingView ? -20 : 0)
                        .animation(.easeInOut(duration: 0.3), value: showingRecordingView)
                    
                    // Main calendar view - Allow it to expand
                    CalendarGridView(
                        showingRecordingView: $showingRecordingView,
                        sharedVideoRecorder: sharedVideoRecorder // ✅ Pass singleton instance
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, showingRecordingView ? -40 : 10)
                    .animation(.easeInOut(duration: 0.3), value: showingRecordingView)
                }
            }
        }
        .frame(minWidth: 700, maxWidth: .infinity, minHeight: 750, maxHeight: .infinity)
    }
    
    private var headerView: some View {
        ZStack {
            // Centered title
            VStack(spacing: 4) {
                Text("DailyFrame")
                    .font(.largeTitle)
                    .fontWeight(.thin)
                    .foregroundStyle(.primary)
                
                Text("Your daily learning journey")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Right-aligned button
            HStack {
                Spacer()
                
                Button(action: {
                    // ✅ Use singleton instance
                    sharedVideoRecorder.showVideosInFinder()
                }) {
                    HStack(spacing: 4) {
                        Text("Videos")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.quaternary.opacity(0.5), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .help("Open videos folder")
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
        .padding(.horizontal, 20)
    }
}

// Visual effect view for the background blur
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }
    
    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

#Preview {
    ContentView()
        .modelContainer(for: DiaryEntry.self, inMemory: true)
}
