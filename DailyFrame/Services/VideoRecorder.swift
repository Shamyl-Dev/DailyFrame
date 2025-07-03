@preconcurrency import AVFoundation
import SwiftUI
import Combine

@MainActor
class VideoRecorder: NSObject, ObservableObject {
    // 🔧 NEW: Singleton pattern to prevent multiple instances
    static let shared = VideoRecorder()
    
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var hasPermission = false
    @Published var errorMessage: String?
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var isSessionActive = false // 🔧 NEW: Track if session is active
    
    private var captureSession: AVCaptureSession?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private var movieFileOutput: AVCaptureMovieFileOutput?
    private var recordingTimer: Timer?
    private var currentOutputURL: URL?
    private var isSessionConfigured = false
    
    private let sessionQueue = DispatchQueue(label: "session queue")
    
    // 🔧 UPDATED: Private initializer - NO auto-initialization
    private override init() {
        super.init()
        print("🎥 VideoRecorder singleton initialized (camera OFF)")
        // 🔧 REMOVED: Don't auto-check permissions on init
        // Task { await checkPermissions() }
    }
    
    // 🔧 NEW: Initialize camera only when needed
    func initializeCamera() async {
        print("🎥 Initializing camera on demand...")
        
        guard !isSessionConfigured else {
            print("📹 Camera already initialized")
            await startSession()
            return
        }
        
        await checkPermissions()
    }
    
    // 🔧 NEW: Shutdown camera when not needed
    func shutdownCamera() {
        print("🎥 Shutting down camera...")
        
        // Stop recording if active
        if isRecording {
            Task {
                await stopRecording()
            }
        }
        
        // Stop session
        if let session = captureSession {
            Task.detached {
                if session.isRunning {
                    print("🛑 Stopping camera session...")
                    session.stopRunning()
                }
                
                Task { @MainActor in
                    self.isSessionActive = false
                    print("📹 Camera session stopped")
                }
            }
        }
    }
    
    // 🔧 UPDATED: Only check permissions, don't auto-setup
    func checkPermissions() async {
        print("🔍 Checking permissions...")
        
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        print("📹 Camera status: \(cameraStatus.rawValue) (\(cameraStatus))")
        print("🎤 Microphone status: \(microphoneStatus.rawValue) (\(microphoneStatus))")
        
        let cameraAuthorized: Bool
        let microphoneAuthorized: Bool
        
        // Request camera permission if needed
        if cameraStatus == .notDetermined {
            print("📹 Requesting camera permission...")
            cameraAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            print("📹 Camera result: \(cameraAuthorized)")
        } else {
            cameraAuthorized = cameraStatus == .authorized
        }
        
        // Request microphone permission if needed
        if microphoneStatus == .notDetermined {
            print("🎤 Requesting microphone permission...")
            microphoneAuthorized = await AVCaptureDevice.requestAccess(for: .audio)
            print("🎤 Microphone result: \(microphoneAuthorized)")
        } else {
            microphoneAuthorized = microphoneStatus == .authorized
        }
        
        // Update state
        hasPermission = cameraAuthorized && microphoneAuthorized
        
        if hasPermission {
            print("✅ All permissions granted - setting up session")
            errorMessage = nil
            await setupCaptureSession()
        } else {
            if !cameraAuthorized {
                errorMessage = "Camera permission is required. Please enable it in System Preferences → Privacy & Security → Camera."
            } else if !microphoneAuthorized {
                errorMessage = "Microphone permission is required. Please enable it in System Preferences → Privacy & Security → Microphone."
            }
            print("❌ Missing permissions: \(errorMessage ?? "")")
        }
    }
    
    // 🔧 UPDATED: Setup but don't auto-start
    private func setupCaptureSession() async {
        guard !isSessionConfigured else {
            print("📹 Session already configured")
            return
        }
        
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                let session = AVCaptureSession()
                session.beginConfiguration()
                
                if session.canSetSessionPreset(.high) {
                    session.sessionPreset = .high
                }
                
                var videoDeviceInput: AVCaptureDeviceInput?
                var audioDeviceInput: AVCaptureDeviceInput?
                
                // Add video input
                do {
                    var videoDevice: AVCaptureDevice?
                    
                    // Try different camera discovery methods
                    videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                    
                    if videoDevice == nil {
                        videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                    }
                    
                    if videoDevice == nil {
                        videoDevice = AVCaptureDevice.default(for: .video)
                    }
                    
                    if videoDevice == nil {
                        let discoverySession = AVCaptureDevice.DiscoverySession(
                            deviceTypes: [.builtInWideAngleCamera, .external],
                            mediaType: .video,
                            position: .unspecified
                        )
                        videoDevice = discoverySession.devices.first
                    }
                    
                    guard let device = videoDevice else {
                        Task { @MainActor in
                            self.errorMessage = "No camera devices found"
                        }
                        throw RecorderError.noCamera
                    }
                    
                    print("📹 Using camera: \(device.localizedName)")
                    
                    let deviceInput = try AVCaptureDeviceInput(device: device)
                    
                    if session.canAddInput(deviceInput) {
                        session.addInput(deviceInput)
                        videoDeviceInput = deviceInput
                        print("📹 Video input added successfully")
                    } else {
                        throw RecorderError.cannotAddInput
                    }
                } catch {
                    Task { @MainActor in
                        self.errorMessage = "Failed to setup camera: \(error.localizedDescription)"
                    }
                    session.commitConfiguration()
                    continuation.resume()
                    return
                }
                
                // Add audio input
                do {
                    guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
                        throw RecorderError.noMicrophone
                    }
                    
                    print("🎤 Using microphone: \(audioDevice.localizedName)")
                    
                    let deviceInput = try AVCaptureDeviceInput(device: audioDevice)
                    
                    if session.canAddInput(deviceInput) {
                        session.addInput(deviceInput)
                        audioDeviceInput = deviceInput
                        print("🎤 Audio input added successfully")
                    } else {
                        throw RecorderError.cannotAddInput
                    }
                } catch {
                    Task { @MainActor in
                        self.errorMessage = "Failed to setup microphone: \(error.localizedDescription)"
                    }
                    session.commitConfiguration()
                    continuation.resume()
                    return
                }
                
                // Add movie file output
                let movieFileOutput = AVCaptureMovieFileOutput()
                if session.canAddOutput(movieFileOutput) {
                    session.addOutput(movieFileOutput)
                    print("📹 Movie output added successfully")
                    
                    // Configure connections
                    if let videoConnection = movieFileOutput.connection(with: .video) {
                        videoConnection.videoRotationAngle = 0
                        videoConnection.isEnabled = true
                        print("📹 Video connection configured and enabled")
                    }
                    
                    if let audioConnection = movieFileOutput.connection(with: .audio) {
                        audioConnection.isEnabled = true
                        print("🎤 Audio connection configured and enabled")
                    }
                    
                    Task { @MainActor in
                        self.movieFileOutput = movieFileOutput
                    }
                } else {
                    Task { @MainActor in
                        self.errorMessage = "Failed to add movie output"
                    }
                    session.commitConfiguration()
                    continuation.resume()
                    return
                }
                
                session.commitConfiguration()
                print("📹 Session configuration committed")
                
                Task { @MainActor in
                    self.captureSession = session
                    self.videoDeviceInput = videoDeviceInput
                    self.audioDeviceInput = audioDeviceInput
                    
                    let previewLayer = AVCaptureVideoPreviewLayer(session: session)
                    previewLayer.videoGravity = .resizeAspectFill
                    self.previewLayer = previewLayer
                    self.errorMessage = nil
                    self.isSessionConfigured = true
                    
                    print("📹 Capture session configured (but not started)")
                    
                    // 🔧 CHANGED: Don't auto-start session
                    // The session will be started when needed
                }
                
                continuation.resume()
            }
        }
    }
    
    // 🔧 UPDATED: Start session only when needed
    nonisolated func startSession() async {
        await MainActor.run {
            guard let session = self.captureSession else { 
                print("❌ No capture session to start")
                return 
            }
            
            guard !session.isRunning else {
                print("📹 Session already running")
                self.isSessionActive = true
                return
            }
            
            print("📹 Starting capture session...")
            
            Task.detached {
                session.startRunning()
                
                // Wait for session to stabilize
                try? await Task.sleep(for: .milliseconds(500))
                
                Task { @MainActor in
                    self.isSessionActive = session.isRunning
                    print("📹 Session started: \(session.isRunning)")
                }
            }
        }
    }
    
    // 🔧 UPDATED: Stop session when not needed
    nonisolated func stopSession() async {
        await MainActor.run {
            guard let session = self.captureSession else { return }
            
            print("🛑 Stopping capture session...")
            
            Task.detached {
                if session.isRunning {
                    session.stopRunning()
                    print("🛑 Capture session stopped")
                }
                
                Task { @MainActor in
                    self.isSessionActive = false
                }
            }
        }
    }
    
    func resetSession() {
        print("🔄 Resetting video recorder session...")
        
        // Stop any recording first
        if isRecording {
            Task {
                await stopRecording()
            }
        }
        
        // Stop timer
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Reset state
        isRecording = false
        recordingDuration = 0
        currentOutputURL = nil
        
        // Clean up session on background queue
        if let session = captureSession {
            Task.detached {
                if session.isRunning {
                    print("🛑 Stopping existing session...")
                    session.stopRunning()
                    
                    // Wait for session to fully stop
                    try? await Task.sleep(for: .milliseconds(200))
                }
                
                Task { @MainActor in
                    self.captureSession = nil
                    self.videoDeviceInput = nil
                    self.audioDeviceInput = nil
                    self.movieFileOutput = nil
                    self.previewLayer = nil
                    self.isSessionConfigured = false
                    print("✅ Session reset complete")
                }
            }
        }
    }
    
    func startRecording(for date: Date) async -> URL? {
        guard let movieFileOutput = movieFileOutput else {
            errorMessage = "Movie output not available"
            print("❌ Movie output not available")
            return nil
        }
        
        guard !movieFileOutput.isRecording else {
            errorMessage = "Already recording"
            print("❌ Already recording")
            return nil
        }
        
        // Ensure the session is available
        guard let captureSession = captureSession else {
            errorMessage = "Capture session not available"
            print("❌ Capture session not available")
            return nil
        }
        
        // Check if session is running, start if needed
        if !captureSession.isRunning {
            print("📹 Session not running, starting now...")
            await withCheckedContinuation { continuation in
                Task.detached {
                    captureSession.startRunning()
                    
                    // Wait a moment for the session to stabilize
                    try? await Task.sleep(for: .milliseconds(500))
                    
                    continuation.resume()
                }
            }
        }
        
        // Check connections
        let activeConnections = movieFileOutput.connections.filter { $0.isEnabled && $0.isActive }
        print("📹 Active connections: \(activeConnections.count)")
        
        guard !activeConnections.isEmpty else {
            errorMessage = "No active camera/microphone connections available"
            print("❌ No active connections available")
            print("📊 Session running: \(captureSession.isRunning)")
            return nil
        }
        
        print("📹 Starting recording with \(activeConnections.count) active connections")
        
        // 🎬 FIXED: Use Documents directory (always accessible)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosDirectory = documentsPath.appendingPathComponent("DailyFrame", isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: videosDirectory, withIntermediateDirectories: true)
            print("📁 Created directory: \(videosDirectory.path)")
        } catch {
            errorMessage = "Failed to create video directory: \(error.localizedDescription)"
            print("❌ Failed to create directory: \(error)")
            return nil
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let filename = "\(dateFormatter.string(from: date)).mov"
        let outputURL = videosDirectory.appendingPathComponent(filename)
        
        // Remove existing file if it exists
        try? FileManager.default.removeItem(at: outputURL)
        
        currentOutputURL = outputURL
        
        print("📹 Saving video to: \(outputURL.path)")
        
        return await withCheckedContinuation { continuation in
            Task.detached {
                // Start recording
                movieFileOutput.startRecording(to: outputURL, recordingDelegate: self)
                print("📹 Recording started to: \(outputURL)")
                
                Task { @MainActor in
                    self.isRecording = true
                    self.recordingDuration = 0
                    self.startTimer()
                }
                
                continuation.resume(returning: outputURL)
            }
        }
    }
    
    func stopRecording() async -> URL? {
        guard let movieFileOutput = movieFileOutput, movieFileOutput.isRecording else {
            errorMessage = "Not currently recording"
            return nil
        }
        
        let outputURL = currentOutputURL
        
        return await withCheckedContinuation { continuation in
            Task.detached {
                movieFileOutput.stopRecording()
                
                Task { @MainActor in
                    self.isRecording = false
                    self.stopTimer()
                }
                
                continuation.resume(returning: outputURL)
            }
        }
    }
    
    private func startTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 1
            }
        }
    }
    
    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    deinit {
        print("🗑️ VideoRecorder deinit - cleaning up...")
        
        let timer = recordingTimer
        let session = captureSession
        
        timer?.invalidate()
        
        Task.detached {
            if let session = session, session.isRunning {
                print("🛑 Stopping session in deinit...")
                session.stopRunning()
                
                // Wait for session to fully stop
                try? await Task.sleep(for: .milliseconds(100))
                print("✅ Session cleanup complete in deinit")
            }
        }
    }
    
    // Add this method to your VideoRecorder class for debugging:
    func debugCameraDevices() {
        print("🔍 Available camera devices:")
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        ).devices
        
        for device in devices {
            print("📹 Device: \(device.localizedName) - Position: \(device.position.rawValue) - Connected: \(device.isConnected)")
        }
        
        if devices.isEmpty {
            print("❌ No camera devices found")
        }
    }
    
    // Add these methods to your VideoRecorder class:
    
    func showVideosInFinder() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosDirectory = documentsPath.appendingPathComponent("DailyFrame", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: videosDirectory, withIntermediateDirectories: true)
        
        // Open in Finder
        NSWorkspace.shared.open(videosDirectory)
        print("📁 Opening videos folder: \(videosDirectory.path)")
    }
    
    func getVideoURL(for date: Date) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosDirectory = documentsPath.appendingPathComponent("DailyFrame", isDirectory: true)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let filename = "\(dateFormatter.string(from: date)).mov"
        let videoURL = videosDirectory.appendingPathComponent(filename)
        
        return FileManager.default.fileExists(atPath: videoURL.path) ? videoURL : nil
    }
    
    func getVideosDirectoryPath() -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosDirectory = documentsPath.appendingPathComponent("DailyFrame", isDirectory: true)
        return videosDirectory.path
    }
    
    func getAllVideoFiles() -> [URL] {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosDirectory = documentsPath.appendingPathComponent("DailyFrame", isDirectory: true)
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: videosDirectory, includingPropertiesForKeys: nil)
            return files.filter { $0.pathExtension.lowercased() == "mov" }
        } catch {
            print("❌ Error reading videos directory: \(error)")
            return []
        }
    }
    
    // 🔧 NEW: Add the missing refreshPermissions method
    func refreshPermissions() {
        print("🔄 Refreshing permissions...")
        Task {
            await checkPermissions()
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension VideoRecorder: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        // Recording started
    }
    
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.errorMessage = "Recording failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Error Types
enum RecorderError: Error, LocalizedError {
    case noCamera
    case noMicrophone
    case cannotAddInput
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .noCamera:
            return "No camera available"
        case .noMicrophone:
            return "No microphone available"
        case .cannotAddInput:
            return "Cannot add input to capture session"
        case .permissionDenied:
            return "Camera or microphone permission denied"
        }
    }
}