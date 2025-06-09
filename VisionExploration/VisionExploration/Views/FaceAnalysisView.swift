//
//  FaceAnalysisView.swift
//  VisionExploration
//
//  Created by M Naufal Badruttamam on 09/06/25.
//

import SwiftUI
import Vision
import PhotosUI

struct FaceAnalysisView: View {
    @State private var selectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var analysisResults: [FaceAnalysisResult] = []
    @State private var isAnalyzing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(radius: 5)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 250)
                        .overlay(
                            VStack {
                                Image(systemName: "person.crop.rectangle")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                Text("Select Image for Analysis")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                        )
                }
                
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Analyze Photo", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                }
                
                if isAnalyzing {
                    ProgressView("Analyzing faces...")
                        .padding()
                }
                
                if !analysisResults.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(Array(analysisResults.enumerated()), id: \.offset) { index, analysis in
                                FaceAnalysisCard(analysis: analysis, faceNumber: index + 1)
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Face Analysis")
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                    await analyzeFaces(in: image)
                }
            }
        }
    }
    
    @MainActor
    func analyzeFaces(in image: UIImage) async {
        isAnalyzing = true
        analysisResults = []
        
        guard let resizedImage = resizeImageForAnalysis(image, maxSize: 1024),
              let cgImage = resizedImage.cgImage else {
            isAnalyzing = false
            return
        }
        
        let request = VNDetectFaceLandmarksRequest { request, error in
            if let error = error {
                print("Face analysis error: \(error)")
                DispatchQueue.main.async {
                    self.isAnalyzing = false
                }
                return
            }
            
            guard let observations = request.results as? [VNFaceObservation] else {
                DispatchQueue.main.async {
                    self.isAnalyzing = false
                }
                return
            }
            
            DispatchQueue.main.async {
                for observation in observations {
                    let analysis = FaceAnalysisResult(
                        confidence: observation.confidence,
                        hasSmile: self.detectSmile(from: observation),
                        eyesOpen: self.detectEyesOpen(from: observation),
                        faceAngle: observation.yaw?.doubleValue ?? 0.0,
                        quality: self.assessQuality(from: observation)
                    )
                    self.analysisResults.append(analysis)
                }
                self.isAnalyzing = false
            }
        }
        
        request.revision = VNDetectFaceLandmarksRequestRevision3
        
        let handler = VNImageRequestHandler(cgImage: cgImage)
        do {
            try handler.perform([request])
        } catch {
            print("Face analysis error: \(error)")
            isAnalyzing = false
        }
    }
    
    func resizeImageForAnalysis(_ image: UIImage, maxSize: CGFloat) -> UIImage? {
        let size = image.size
        let aspectRatio = size.width / size.height
        
        var newSize: CGSize
        if size.width > size.height {
            newSize = CGSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            newSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }
        
        if size.width <= maxSize && size.height <= maxSize {
            return image
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    func detectSmile(from observation: VNFaceObservation) -> Bool {
        guard let landmarks = observation.landmarks,
              let outerLips = landmarks.outerLips else { return false }
        
        let points = outerLips.normalizedPoints
        guard points.count >= 6 else { return false }
        
        let leftCorner = points[0]
        let rightCorner = points[points.count/2]
        let topLip = points[points.count/4]
        let bottomLip = points[3*points.count/4]
        
        let lipHeight = abs(topLip.y - bottomLip.y)
        let lipWidth = abs(rightCorner.x - leftCorner.x)
        let cornerElevation = (leftCorner.y + rightCorner.y) / 2
        let centerElevation = (topLip.y + bottomLip.y) / 2
        
        let widthHeightRatio = lipWidth / max(lipHeight, 0.001)
        let isWideSmile = widthHeightRatio > 3.0
        let areCornerselevated = cornerElevation > centerElevation
        
        return isWideSmile || areCornerselevated
    }
    
    func detectEyesOpen(from observation: VNFaceObservation) -> Bool {
        guard let landmarks = observation.landmarks else { return true }
        
        var eyesOpenCount = 0
        
        if let leftEye = landmarks.leftEye {
            let points = leftEye.normalizedPoints
            if points.count >= 6 {
                let topPoints = Array(points.prefix(3))
                let bottomPoints = Array(points.suffix(3))
                let avgTop = topPoints.reduce(CGFloat(0)) { $0 + $1.y } / CGFloat(topPoints.count)
                let avgBottom = bottomPoints.reduce(CGFloat(0)) { $0 + $1.y } / CGFloat(bottomPoints.count)
                let eyeOpenness = abs(avgTop - avgBottom)
                
                if eyeOpenness > 0.008 {
                    eyesOpenCount += 1
                }
            }
        }
        
        if let rightEye = landmarks.rightEye {
            let points = rightEye.normalizedPoints
            if points.count >= 6 {
                let topPoints = Array(points.prefix(3))
                let bottomPoints = Array(points.suffix(3))
                let avgTop = topPoints.reduce(CGFloat(0)) { $0 + $1.y } / CGFloat(topPoints.count)
                let avgBottom = bottomPoints.reduce(CGFloat(0)) { $0 + $1.y } / CGFloat(bottomPoints.count)
                let eyeOpenness = abs(avgTop - avgBottom)
                
                if eyeOpenness > 0.008 {
                    eyesOpenCount += 1
                }
            }
        }
        
        return eyesOpenCount >= 1
    }
    
    func assessQuality(from observation: VNFaceObservation) -> Double {
        let confidence = Double(observation.confidence)
        let hasLandmarks = observation.landmarks != nil ? 0.15 : 0.0
        let faceSize = observation.boundingBox.width * observation.boundingBox.height
        let sizeScore = min(Double(faceSize) * 3, 0.25)
        
        var landmarkScore = 0.0
        if let landmarks = observation.landmarks {
            var landmarkCount = 0
            if landmarks.leftEye != nil { landmarkCount += 1 }
            if landmarks.rightEye != nil { landmarkCount += 1 }
            if landmarks.nose != nil { landmarkCount += 1 }
            if landmarks.outerLips != nil { landmarkCount += 1 }
            landmarkScore = Double(landmarkCount) * 0.05
        }
        
        let yawAngle = abs(observation.yaw?.doubleValue ?? 0.0)
        let rollAngle = abs(observation.roll?.doubleValue ?? 0.0)
        let angleScore = max(0, 0.1 - (yawAngle + rollAngle) / 10.0)
        
        return min(confidence + hasLandmarks + sizeScore + landmarkScore + angleScore, 1.0)
    }
}
