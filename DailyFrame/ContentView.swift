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
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background with subtle blur
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .ignoresSafeArea(.all) // Ensure it covers everything
                
                VStack(spacing: 0) {
                    // App title - smoother transition
                    headerView
                        .opacity(showingRecordingView ? 0 : 1)
                        .scaleEffect(showingRecordingView ? 0.95 : 1.0, anchor: .top)
                        .offset(y: showingRecordingView ? -20 : 0)
                        .animation(.easeInOut(duration: 0.3), value: showingRecordingView)
                    
                    // Main calendar view - Allow it to expand
                    CalendarGridView(showingRecordingView: $showingRecordingView)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, showingRecordingView ? -40 : 10)
                        .animation(.easeInOut(duration: 0.3), value: showingRecordingView)
                }
            }
        }
        .frame(minWidth: 700, maxWidth: .infinity, minHeight: 750, maxHeight: .infinity)
    }
    
    private var headerView: some View {
        VStack(spacing: 4) {
            Text("DailyFrame")
                .font(.largeTitle)
                .fontWeight(.thin)
                .foregroundStyle(.primary)
            
            Text("Your daily learning journey")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
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
