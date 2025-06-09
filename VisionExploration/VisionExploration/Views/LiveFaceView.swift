//
//  LiveFaceView.swift
//  VisionExploration
//
//  Created by M Naufal Badruttamam on 09/06/25.
//

import SwiftUI
import Vision
import Combine
import AVFoundation

struct LiveFaceView: View {
    @StateObject private var cameraManager = SimpleCameraManager()
    @State private var isActive = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isActive {
                    ZStack {
                        if cameraManager.isRunning {
                            CameraPreview(session: cameraManager.session)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            
                            FaceOverlay(faces: cameraManager.detectedFaces)
                        } else {
                            Rectangle()
                                .fill(Color.black)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    ProgressView("Starting camera...")
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    
                    VStack(spacing: 10) {
                        Text("Faces: \(cameraManager.detectedFaces.count)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(20)
                        
                        Button(action: {
                            isActive = false
                            cameraManager.stopSession()
                        }) {
                            Text("Stop Camera")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                } else {
                    VStack(spacing: 30) {
                        Image(systemName: "camera.circle")
                            .font(.system(size: 100))
                            .foregroundColor(.blue)
                        
                        Text("Live Face Detection")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Tap to start camera")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            isActive = true
                            cameraManager.startSession()
                        }) {
                            Text("Start Camera")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Live Detection")
        }
        .onDisappear {
            isActive = false
            cameraManager.stopSession()
        }
    }
}
