//
//  FaceInfoCard.swift
//  VisionExploration
//
//  Created by M Naufal Badruttamam on 09/06/25.
//

import SwiftUI
import Vision

struct FaceInfoCard: View {
    let face: FaceInfo
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Face \(index)")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(Int(face.confidence * 100))%")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Confidence: \(String(format: "%.1f", face.confidence * 100))%")
                    Text("Position: (\(String(format: "%.2f", face.boundingBox.origin.x)), \(String(format: "%.2f", face.boundingBox.origin.y)))")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
}
