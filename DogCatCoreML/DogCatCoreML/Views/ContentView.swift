import SwiftUI
import CoreML
import Vision
import PhotosUI

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var classificationResult: String = ""
    @State private var confidence: Double = 0.0
    @State private var isLoading = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var showingSamplePicker = false
    
    let sampleImages = ["dog_1", "dog_2", "dog_3", "dog_4", "cat_1", "cat_2", "cat_3", "cat_4"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Dog vs Cat Classifier")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 300, maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        .shadow(radius: 5)
                } else {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 300, height: 300)
                        .overlay(
                            VStack {
                                Image(systemName: "photo")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                Text("Pilih Gambar")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                        )
                }
                
                HStack(spacing: 15) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("Gallery", systemImage: "photo.on.rectangle")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    
                    Button(action: { showingSamplePicker = true }) {
                        Label("Sample", systemImage: "rectangle.stack")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                }
                
                if !classificationResult.isEmpty {
                    VStack(spacing: 10) {
                        Text("Hasil Klasifikasi:")
                            .font(.headline)
                        
                        Text(classificationResult)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(classificationResult.lowercased().contains("dog") ? .brown : .orange)
                        
                        Text("Confidence: \(Int(confidence * 100))%")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        ProgressView(value: confidence)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .frame(width: 200)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                
                if isLoading {
                    ProgressView("Menganalisis gambar...")
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                    await classifyImage(image)
                }
            }
        }
        .sheet(isPresented: $showingSamplePicker) {
            SampleImagePicker(sampleImages: sampleImages) { imageName in
                if let image = UIImage(named: imageName) {
                    selectedImage = image
                    Task {
                        await classifyImage(image)
                    }
                }
                showingSamplePicker = false
            }
        }
    }
    
    @MainActor
    func classifyImage(_ image: UIImage) async {
        isLoading = true
        classificationResult = ""
        confidence = 0.0
        
        do {
            guard let modelURL = Bundle.main.url(forResource: "DogCat", withExtension: "mlmodelc") else {
                classificationResult = "Model tidak ditemukan"
                isLoading = false
                return
            }
            
            let model = try MLModel(contentsOf: modelURL)
            
            guard let pixelBuffer = image.toCVPixelBuffer(width: 299, height: 299) else {
                classificationResult = "Gagal memproses gambar"
                isLoading = false
                return
            }
            
            let input = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: pixelBuffer)])
            let prediction = try await model.prediction(from: input)
            
            if let label = prediction.featureValue(for: "target")?.stringValue {
                classificationResult = label.capitalized
                
                if let probabilities = prediction.featureValue(for: "targetProbability"),
                   probabilities.type == .dictionary {
                    let probabilityDict = probabilities.dictionaryValue
                    
                    for (key, value) in probabilityDict {
                        if let keyString = key as? String,
                           keyString.lowercased() == label.lowercased() {
                            confidence = value.doubleValue
                            break
                        }
                    }
                }
            } else {
                classificationResult = "Tidak dapat mengklasifikasi"
            }
            
        } catch {
            classificationResult = "Error: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
