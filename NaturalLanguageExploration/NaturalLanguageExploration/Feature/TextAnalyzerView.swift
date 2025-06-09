//
//  TextAnalyzerView.swift
//  NaturalLanguageExploration
//
//  Created by M Naufal Badruttamam on 09/06/25.
//

import SwiftUI
import NaturalLanguage

struct TextAnalyzerView: View {
    @State private var inputText = ""
    @State private var wordCount = 0
    @State private var characterCount = 0
    @State private var readingTime = 0
    @State private var sentences = 0
    @State private var dominantLanguage = ""
    @State private var overallSentiment = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Paste your text here:")
                        .font(.headline)
                    
                    TextEditor(text: $inputText)
                        .frame(minHeight: 150)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .onChange(of: inputText) { _ in
                            analyzeText()
                        }
                }
                .padding()
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                    StatCard(title: "Words", value: "\(wordCount)", icon: "textformat")
                    StatCard(title: "Characters", value: "\(characterCount)", icon: "character")
                    StatCard(title: "Reading Time", value: "\(readingTime) min", icon: "clock")
                    StatCard(title: "Sentences", value: "\(sentences)", icon: "text.quote")
                    StatCard(title: "Language", value: dominantLanguage, icon: "globe")
                    StatCard(title: "Sentiment", value: overallSentiment, icon: "heart")
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Text Analyzer")
        }
    }
    
    func analyzeText() {
        guard !inputText.isEmpty else {
            resetStats()
            return
        }
        
        wordCount = inputText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        characterCount = inputText.count
        readingTime = max(1, wordCount / 200)
        sentences = inputText.components(separatedBy: .punctuationCharacters).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(inputText)
        dominantLanguage = recognizer.dominantLanguage?.rawValue.uppercased() ?? "Unknown"
        
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = inputText
        let (sentiment, _) = tagger.tag(at: inputText.startIndex, unit: .paragraph, scheme: .sentimentScore)
        
        if let sentimentScore = sentiment {
            let score = Double(sentimentScore.rawValue) ?? 0.0
            overallSentiment = score > 0.1 ? "Positive" : score < -0.1 ? "Negative" : "Neutral"
        } else {
            overallSentiment = "Unknown"
        }
    }
    
    func resetStats() {
        wordCount = 0
        characterCount = 0
        readingTime = 0
        sentences = 0
        dominantLanguage = ""
        overallSentiment = ""
    }
}

#Preview {
    TextAnalyzerView()
}
