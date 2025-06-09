//
//  SimpleCameraManager.swift
//  VisionExploration
//
//  Created by M Naufal Badruttamam on 09/06/25.
//

import AVFoundation
import Vision
import SwiftUI

class SimpleCameraManager: NSObject, ObservableObject {
    @Published var detectedFaces: [VNFaceObservation] = []
    @Published var isRunning = false

    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "session.queue")
    private var lastProcessTime: CFTimeInterval = 0

    override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .medium

            guard
                let camera = AVCaptureDevice.default(
                    .builtInWideAngleCamera,
                    for: .video,
                    position: .front
                ),
                let input = try? AVCaptureDeviceInput(device: camera)
            else {
                print("Failed to create camera input")
                self.session.commitConfiguration()
                return
            }

            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }

            self.videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(
                    kCVPixelFormatType_32BGRA
                )
            ]
            self.videoOutput.alwaysDiscardsLateVideoFrames = true

            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
                self.videoOutput.setSampleBufferDelegate(
                    self,
                    queue: DispatchQueue(label: "video.queue")
                )
            }

            self.session.commitConfiguration()
        }
    }

    func startSession() {
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isRunning = self.session.isRunning
                }
            }
        }
    }

    func stopSession() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isRunning = false
                self.detectedFaces = []
            }
        }
    }
}

extension SimpleCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastProcessTime > 0.1 else { return }
        lastProcessTime = currentTime

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }

        let request = VNDetectFaceRectanglesRequest { [weak self] request, _ in
            guard let faces = request.results as? [VNFaceObservation] else {
                return
            }

            DispatchQueue.main.async {
                self?.detectedFaces = faces
            }
        }

        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
            .perform([request])
    }
}
