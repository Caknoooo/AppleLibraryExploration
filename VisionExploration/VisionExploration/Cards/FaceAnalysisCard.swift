//
//  FaceAnalysisCard.swift
//  VisionExploration
//
//  Created by M Naufal Badruttamam on 09/06/25.
//

import SwiftUI

struct FaceAnalysisCard: View {
    let analysis: FaceAnalysisResult
    let faceNumber: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Face \(faceNumber)")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("Quality: \(Int(analysis.quality * 100))%")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(qualityColor.opacity(0.2))
                    .cornerRadius(8)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                AnalysisItem(title: "Confidence", value: "\(Int(analysis.confidence * 100))%", icon: "checkmark.circle")
                AnalysisItem(title: "Smile", value: analysis.hasSmile ? "Yes" : "No", icon: analysis.hasSmile ? "face.smiling" : "face.dashed")
                AnalysisItem(title: "Eyes Open", value: analysis.eyesOpen ? "Yes" : "No", icon: analysis.eyesOpen ? "eye" : "eye.slash")
                AnalysisItem(title: "Face Angle", value: "\(Int(abs(analysis.faceAngle * 180 / Double.pi)))°", icon: "rotate.3d")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    var qualityColor: Color {
        analysis.quality > 0.7 ? .green : analysis.quality > 0.4 ? .orange : .red
    }
}
