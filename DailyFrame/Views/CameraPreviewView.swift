import SwiftUI
import AVFoundation

struct CameraPreviewView: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer?
    
    func makeNSView(context: Context) -> PreviewNSView {
        let view = PreviewNSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        
        // 🔧 OPTIMIZED: Performance optimizations
        view.layerContentsRedrawPolicy = .never
        view.layerUsesCoreImageFilters = false
        
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
    private var isLayoutInProgress = false
    
    // 🔧 OPTIMIZED: Proper cleanup
    deinit {
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
    }
    
    override func layout() {
        guard !isLayoutInProgress else { return }
        isLayoutInProgress = true
        
        super.layout()
        
        // 🔧 OPTIMIZED: Batch layer updates
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer?.frame = bounds
        CATransaction.commit()
        
        isLayoutInProgress = false
    }
    
    func setPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        // Remove existing layer properly
        if let existingLayer = previewLayer {
            existingLayer.removeFromSuperlayer()
        }
        
        // Add new layer with optimizations
        previewLayer = layer
        layer.frame = bounds
        layer.videoGravity = .resizeAspectFill
        
        // 🔧 OPTIMIZED: Performance settings
        layer.backgroundColor = NSColor.black.cgColor
        layer.isOpaque = true
        layer.allowsEdgeAntialiasing = false
        layer.shouldRasterize = false
        
        self.layer?.addSublayer(layer)
    }
    
    // 🔧 OPTIMIZED: View properties
    override var isOpaque: Bool { true }
    override var wantsUpdateLayer: Bool { true }
}