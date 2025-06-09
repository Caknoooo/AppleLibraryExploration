//
//  CameraView.swift
//  VisionExploration
//
//  Created by M Naufal Badruttamam on 09/06/25.
//

import SwiftUI
import Vision
import AVFoundation

class CameraView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    func setupPreview(with session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        guard let previewLayer = previewLayer else { return }
        
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = bounds
        layer.addSublayer(previewLayer)
    }
    
    func updatePreviewFrame() {
        DispatchQueue.main.async {
            self.previewLayer?.frame = self.bounds
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}
