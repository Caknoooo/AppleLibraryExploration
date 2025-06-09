//
//  SampleImagePicker.swift
//  DogCatCoreML
//
//  Created by M Naufal Badruttamam on 09/06/25.
//
import SwiftUI

struct SampleImagePicker: View {
    let sampleImages: [String]
    let onImageSelected: (String) -> Void
    
    var body: some View {
        NavigationView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 20) {
                ForEach(sampleImages, id: \.self) { imageName in
                    Button(action: {
                        onImageSelected(imageName)
                    }) {
                        if let image = UIImage(named: imageName) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 150, height: 150)
                                .clipped()
                                .cornerRadius(10)
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 150, height: 150)
                                .overlay(
                                    Text(imageName)
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("Sample Images")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
