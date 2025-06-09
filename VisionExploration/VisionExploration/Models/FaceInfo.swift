//
//  FaceInfo.swift
//  VisionExploration
//
//  Created by M Naufal Badruttamam on 09/06/25.
//

import SwiftUI

struct FaceInfo {
    let id: Int
    let confidence: Float
    let boundingBox: CGRect
    let landmarks: FaceLandmarks?
}
