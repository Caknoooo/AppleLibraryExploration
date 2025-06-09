//
//  SentimentMeterView.swift
//  NaturalLanguageExploration
//
//  Created by M Naufal Badruttamam on 09/06/25.
//

import SwiftUI
import NaturalLanguage

struct SentimentMeterView: View {
    @State private var inputText = ""
    @State private var overallSentiment: Double = 0.0
    @State private var sentenceAnalysis: [(text: String, sentiment: Double)] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Analyze sentiment:")
                        .font(.headline)
                    
                    TextEditor(text: $inputText)
                        .frame(height: 120)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .onChange(of: inputText) { _ in
                            analyzeSentiment()
                        }
                }
                .padding()
                
                if !inputText.isEmpty {
                    SentimentGauge(sentiment: overallSentiment)
                        .padding()
                    
                    if !sentenceAnalysis.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(Array(sentenceAnalysis.enumerated()), id: \.offset) { index, item in
                                    SentenceCard(text: item.text, sentiment: item.sentiment)
                                }
                            }
                            .padding()
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Sentiment Meter")
        }
    }
    
    func analyzeSentiment() {
        guard !inputText.isEmpty else {
            overallSentiment = 0.0
            sentenceAnalysis = []
            return
        }
        
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = inputText
        
        let (sentiment, _) = tagger.tag(at: inputText.startIndex, unit: .paragraph, scheme: .sentimentScore)
        overallSentiment = Double(sentiment?.rawValue ?? "0") ?? 0.0
        
        var sentences: [(text: String, sentiment: Double)] = []
        tagger.enumerateTags(in: inputText.startIndex..<inputText.endIndex, unit: .sentence, scheme: .sentimentScore) { tag, range in
            let sentence = String(inputText[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            let sentimentScore = Double(tag?.rawValue ?? "0") ?? 0.0
            if !sentence.isEmpty {
                sentences.append((text: sentence, sentiment: sentimentScore))
            }
            return true
        }
        sentenceAnalysis = sentences
    }
}
