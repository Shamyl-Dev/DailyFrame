import SwiftUI
import AVFoundation

struct CameraPreviewView: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer?
    
    func makeNSView(context: Context) -> PreviewNSView {
        let view = PreviewNSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        return view
    }
    
    func updateNSView(_ nsView: PreviewNSView, context: Context) {
        if let previewLayer = previewLayer {
            nsView.setPreviewLayer(previewLayer)
        }
    }
}

class PreviewNSView: NSView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func layout() {
        super.layout()
        previewLayer?.frame = bounds
    }
    
    func setPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        // Remove existing layer
        previewLayer?.removeFromSuperlayer()
        
        // Add new layer
        previewLayer = layer
        layer.frame = bounds
        layer.videoGravity = .resizeAspectFill
        self.layer?.addSublayer(layer)
    }
}