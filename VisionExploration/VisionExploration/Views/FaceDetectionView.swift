//
//  FaceDetectionView.swift
//  VisionExploration
//
//  Created by M Naufal Badruttamam on 09/06/25.
//

import SwiftUI
import Vision
import PhotosUI

struct FaceDetectionView: View {
    @State private var selectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var processedImage: UIImage?
    @State private var faceCount = 0
    @State private var isProcessing = false
    @State private var detectionResults: [FaceInfo] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let image = processedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 400)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(radius: 5)
                } else if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 400)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(radius: 5)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 300)
                        .overlay(
                            VStack {
                                Image(systemName: "photo")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                Text("Select Image")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                        )
                }
                
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Choose Photo", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                
                if isProcessing {
                    ProgressView("Detecting faces...")
                        .padding()
                }
                
                if faceCount > 0 {
                    VStack(spacing: 10) {
                        Text("Faces Detected: \(faceCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(Array(detectionResults.enumerated()), id: \.offset) { index, face in
                                    FaceInfoCard(face: face, index: index + 1)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Face Detection")
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                    await detectFaces(in: image)
                }
            }
        }
    }
    
    @MainActor
    func detectFaces(in image: UIImage) async {
        isProcessing = true
        faceCount = 0
        detectionResults = []
        processedImage = nil
        
        guard let resizedImage = resizeImage(image, targetSize: CGSize(width: 1024, height: 1024)),
              let cgImage = resizedImage.cgImage else {
            isProcessing = false
            return
        }
        
        let request = VNDetectFaceRectanglesRequest { request, error in
            if let error = error {
                print("Face detection error: \(error)")
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
                return
            }
            
            guard let observations = request.results as? [VNFaceObservation] else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
                return
            }
            
            DispatchQueue.main.async {
                self.faceCount = observations.count
                self.processedImage = self.drawFaceBoxes(on: resizedImage, faces: observations)
                
                for (index, observation) in observations.enumerated() {
                    let faceInfo = FaceInfo(
                        id: index,
                        confidence: observation.confidence,
                        boundingBox: observation.boundingBox,
                        landmarks: self.extractLandmarks(from: observation)
                    )
                    self.detectionResults.append(faceInfo)
                }
                
                self.isProcessing = false
            }
        }
        
        request.revision = VNDetectFaceRectanglesRequestRevision3
        
        let handler = VNImageRequestHandler(cgImage: cgImage)
        do {
            try handler.perform([request])
        } catch {
            print("Face detection error: \(error)")
            isProcessing = false
        }
    }
    
    func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage? {
        let size = image.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        
        let ratio = min(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        let rect = CGRect(origin: .zero, size: newSize)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    func drawFaceBoxes(on image: UIImage, faces: [VNFaceObservation]) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        return renderer.image { context in
            image.draw(at: .zero)
            
            context.cgContext.setStrokeColor(UIColor.red.cgColor)
            context.cgContext.setLineWidth(3.0)
            
            for face in faces {
                let boundingBox = face.boundingBox
                let rect = CGRect(
                    x: boundingBox.origin.x * image.size.width,
                    y: (1 - boundingBox.origin.y - boundingBox.height) * image.size.height,
                    width: boundingBox.width * image.size.width,
                    height: boundingBox.height * image.size.height
                )
                context.cgContext.stroke(rect)
            }
        }
    }
    
    func extractLandmarks(from observation: VNFaceObservation) -> FaceLandmarks? {
        guard let landmarks = observation.landmarks else { return nil }
        
        return FaceLandmarks(
            leftEye: landmarks.leftEye?.pointsInImage(imageSize: CGSize(width: 100, height: 100)),
            rightEye: landmarks.rightEye?.pointsInImage(imageSize: CGSize(width: 100, height: 100)),
            nose: landmarks.nose?.pointsInImage(imageSize: CGSize(width: 100, height: 100)),
            mouth: landmarks.innerLips?.pointsInImage(imageSize: CGSize(width: 100, height: 100))
        )
    }
}
