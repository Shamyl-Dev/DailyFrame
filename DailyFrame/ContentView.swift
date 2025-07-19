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
    @State private var showingSidebar = false
    @State private var showingInsights = false           // 👈 Add this line
    @State private var showingMonthlyInsights = false    // 👈 Add this line
    @State private var showingSettings = false
    @State private var sidebarIsClosing = false
    @State private var appColorScheme: ColorScheme? = .dark
    @ObservedObject private var sharedVideoRecorder = VideoRecorder.shared
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Main content
            NavigationStack {
                ZStack {
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
                            sharedVideoRecorder: sharedVideoRecorder
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, showingRecordingView ? -40 : 10)
                        .animation(.easeInOut(duration: 0.3), value: showingRecordingView)
                    }
                }
                .frame(minWidth: 700, maxWidth: .infinity, minHeight: 750, maxHeight: .infinity)
                .onAppear {
                    print("📱 App started - camera remains OFF until needed")
                }
            }
            
            // Sidebar overlay
            if showingSidebar {
                SidebarMenuView(
                    showWeeklyInsights: {
                        sidebarIsClosing = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                            showingInsights = true
                            showingSidebar = false
                            sidebarIsClosing = false
                        }
                    },
                    showMonthlyInsights: {
                        sidebarIsClosing = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                            showingMonthlyInsights = true
                            showingSidebar = false
                            sidebarIsClosing = false
                        }
                    },
                    showVideos: {
                        sidebarIsClosing = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                            sharedVideoRecorder.showVideosInFinder()
                            showingSidebar = false
                            sidebarIsClosing = false
                        }
                    },
                    closeSidebar: {
                        sidebarIsClosing = true
                        DispatchQueue.main.asyncAfter(deadline: .now()) {
                            showingSidebar = false
                            sidebarIsClosing = false
                        }
                    },
                    showSettings: { showingSettings = true },
                    isClosing: sidebarIsClosing,
                    appColorScheme: $appColorScheme // 👈 Add this
                )
                .frame(width: 260)
                .background(.ultraThinMaterial)
                .transition(.move(edge: .leading))
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showingSidebar)
        .sheet(isPresented: $showingInsights) {
            InsightsView()
                .frame(minWidth: 600, minHeight: 500)
        }
        .sheet(isPresented: $showingMonthlyInsights) {
            MonthlyInsightsView()
                .frame(minWidth: 600, minHeight: 500)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(videoRecorder: sharedVideoRecorder)
                .frame(minWidth: 400, minHeight: 320)
        }
        .preferredColorScheme(appColorScheme)
    }
    
    private var headerView: some View {
        ZStack {
            HStack {
                // Hamburger menu button
                Button(action: { showingSidebar = true }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .foregroundStyle(.primary)
                        .padding(8)
                }
                .buttonStyle(.plain)
                .help("Menu")
                Spacer()
            }
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
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
        .padding(.horizontal, 20)
    }
}

struct SidebarMenuView: View {
    var showWeeklyInsights: () -> Void
    var showMonthlyInsights: () -> Void
    var showVideos: () -> Void
    var closeSidebar: () -> Void
    var showSettings: () -> Void
    var isClosing: Bool
    @Binding var appColorScheme: ColorScheme?

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack {
                Text("Menu")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: closeSidebar) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .allowsHitTesting(!isClosing)
            }
            .padding(.bottom, 8)

            Button(action: showWeeklyInsights) {
                Label("Weekly Insights", systemImage: "chart.line.uptrend.xyaxis")
            }
            .buttonStyle(.plain)
            .font(.headline)
            .allowsHitTesting(!isClosing)

            Button(action: showMonthlyInsights) {
                Label("Monthly Insights", systemImage: "calendar")
            }
            .buttonStyle(.plain)
            .font(.headline)
            .allowsHitTesting(!isClosing)

            Button(action: showVideos) {
                Label("Videos", systemImage: "film")
            }
            .buttonStyle(.plain)
            .font(.headline)
            .allowsHitTesting(!isClosing)

            Divider().padding(.vertical, 8)

            // Theme toggle
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.secondary)
                Toggle("Light Mode", isOn: Binding(
                    get: { appColorScheme == .light },
                    set: { appColorScheme = $0 ? .light : .dark }
                ))
                .toggleStyle(SwitchToggleStyle())
            }
            .padding(.top, 8)

            Divider().padding(.vertical, 8)

            Button(action: showSettings) {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.plain)
            .font(.headline)
            .allowsHitTesting(!isClosing)

            Spacer()
        }
        .padding(24)
        .frame(width: 260, alignment: .leading)
        .background(.ultraThinMaterial)
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
