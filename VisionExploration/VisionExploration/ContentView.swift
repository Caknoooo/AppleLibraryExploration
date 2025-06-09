import AVFoundation
import PhotosUI
import SwiftUI
import Vision

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            FaceDetectionView()
                .tabItem {
                    Image(systemName: "face.dashed")
                    Text("Detection")
                }
                .tag(0)

            LiveFaceView()
                .tabItem {
                    Image(systemName: "camera")
                    Text("Live")
                }
                .tag(1)

            FaceAnalysisView()
                .tabItem {
                    Image(systemName: "person.2")
                    Text("Analysis")
                }
                .tag(2)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
