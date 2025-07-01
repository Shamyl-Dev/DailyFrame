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
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background with subtle blur
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 10) {
                        // App title - more compact spacing
                        headerView
                        
                        // Main calendar view
                        CalendarGridView()
                    }
                    .padding(.top, 1)
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
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
