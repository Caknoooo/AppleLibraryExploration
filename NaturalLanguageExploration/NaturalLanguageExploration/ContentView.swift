import NaturalLanguage
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TextAnalyzerView()
                .tabItem {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("Text Analyzer")
                }
                .tag(0)

            LanguageDetectorView()
                .tabItem {
                    Image(systemName: "globe")
                    Text("Language")
                }
                .tag(1)

            SentimentMeterView()
                .tabItem {
                    Image(systemName: "heart.text.square")
                    Text("Sentiment")
                }
                .tag(2)

            SmartKeywordView()
                .tabItem {
                    Image(systemName: "key")
                    Text("Keywords")
                }
                .tag(3)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
