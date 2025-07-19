import SwiftUI
import AVFoundation

struct SettingsView: View {
    @ObservedObject var videoRecorder: VideoRecorder
    @State private var selectedCameraID: String = ""
    @State private var selectedMicID: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Settings")
                .font(.title)
                .fontWeight(.bold)
                .padding(.bottom, 8)

            Text("Camera")
                .font(.headline)
            if videoRecorder.availableVideoDevices.isEmpty {
                Text("No cameras found")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Camera", selection: $selectedCameraID) {
                    ForEach(videoRecorder.availableVideoDevices, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(device.uniqueID)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: selectedCameraID) { newID in
                    videoRecorder.switchCamera(to: newID)
                }
            }

            Text("Microphone")
                .font(.headline)
            if videoRecorder.availableAudioDevices.isEmpty {
                Text("No microphones found")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Microphone", selection: $selectedMicID) {
                    ForEach(videoRecorder.availableAudioDevices, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(device.uniqueID)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: selectedMicID) { newID in
                    videoRecorder.switchMicrophone(to: newID)
                }
            }

            Spacer()
        }
        .padding(32)
        .onAppear {
            videoRecorder.discoverDevices()
            selectedCameraID = videoRecorder.videoDeviceInput?.device.uniqueID ?? ""
            selectedMicID = videoRecorder.audioDeviceInput?.device.uniqueID ?? ""
        }
    }
}