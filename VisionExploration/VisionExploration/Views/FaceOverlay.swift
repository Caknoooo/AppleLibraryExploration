//
//  FaceOverlay.swift
//  VisionExploration
//
//  Created by M Naufal Badruttamam on 09/06/25.
//

import Vision
import SwiftUI

struct FaceOverlay: View {
    let faces: [VNFaceObservation]
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(Array(faces.enumerated()), id: \.offset) { index, face in
                let boundingBox = face.boundingBox
                let rect = CGRect(
                    x: boundingBox.origin.x * geometry.size.width,
                    y: (1 - boundingBox.origin.y - boundingBox.height) * geometry.size.height,
                    width: boundingBox.width * geometry.size.width,
                    height: boundingBox.height * geometry.size.height
                )
                
                Rectangle()
                    .stroke(Color.red, lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
    }
}
