//
//  LanguageDetectorView.swift
//  NaturalLanguageExploration
//
//  Created by M Naufal Badruttamam on 09/06/25.
//

import SwiftUI
import NaturalLanguage

struct LanguageDetectorView: View {
    @State private var inputText = ""
    @State private var detectedLanguages: [(language: String, confidence: Double)] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Enter text to detect language:")
                        .font(.headline)
                    
                    TextEditor(text: $inputText)
                        .frame(height: 120)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .onChange(of: inputText) { _ in
                            detectLanguage()
                        }
                }
                .padding()
                
                if !detectedLanguages.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Detected Languages:")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(Array(detectedLanguages.enumerated()), id: \.offset) { index, item in
                            LanguageRow(
                                language: getLanguageName(from: item.language),
                                code: item.language,
                                confidence: item.confidence,
                                isPrimary: index == 0
                            )
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Language Detector")
        }
    }
    
    func detectLanguage() {
        guard !inputText.isEmpty else {
            detectedLanguages = []
            return
        }
        
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(inputText)
        
        let hypotheses = recognizer.languageHypotheses(withMaximum: 5)
        detectedLanguages = hypotheses.sorted(by: { $0.value > $1.value })
            .map { (language: $0.key.rawValue, confidence: $0.value) }
    }
    
    func getLanguageName(from code: String) -> String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code)?.capitalized ?? code.uppercased()
    }
}
