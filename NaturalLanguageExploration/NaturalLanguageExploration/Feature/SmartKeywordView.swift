//
//  SmartKeywordView.swift
//  NaturalLanguageExploration
//
//  Created by M Naufal Badruttamam on 09/06/25.
//

import NaturalLanguage
import SwiftUI

struct SmartKeywordView: View {
    @State private var inputText = ""
    @State private var keywords: [String] = []
    @State private var entities: [(name: String, type: String)] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Extract keywords and entities:")
                        .font(.headline)
                    
                    TextEditor(text: $inputText)
                        .frame(height: 120)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .onChange(of: inputText) { _ in
                            extractKeywords()
                        }
                }
                .padding()
                
                if !keywords.isEmpty || !entities.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if !keywords.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Keywords:")
                                        .font(.headline)
                                    
                                    FlowLayout(keywords) { keyword in
                                        Text(keyword)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.2))
                                            .cornerRadius(15)
                                            .font(.caption)
                                    }
                                }
                            }
                            
                            if !entities.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Named Entities:")
                                        .font(.headline)
                                    
                                    ForEach(Array(entities.enumerated()), id: \.offset) { index, entity in
                                        HStack {
                                            Text(entity.name)
                                                .fontWeight(.medium)
                                            Spacer()
                                            Text(entity.type)
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.green.opacity(0.2))
                                                .cornerRadius(8)
                                        }
                                        .padding()
                                        .background(Color.gray.opacity(0.05))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Smart Keywords")
        }
    }
    
    func extractKeywords() {
        guard !inputText.isEmpty else {
            keywords = []
            entities = []
            return
        }
        
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = inputText
        
        var extractedKeywords: [String] = []
        var extractedEntities: [(name: String, type: String)] = []
        
        tagger.enumerateTags(in: inputText.startIndex..<inputText.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            let word = String(inputText[range])
            if let lexicalClass = tag?.rawValue,
               (lexicalClass == "Noun" || lexicalClass == "Adjective") && word.count > 3 {
                extractedKeywords.append(word)
            }
            return true
        }
        
        tagger.enumerateTags(in: inputText.startIndex..<inputText.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let nameType = tag {
                let entity = String(inputText[range])
                let type = nameType.rawValue
                extractedEntities.append((name: entity, type: type))
            }
            return true
        }
        
        keywords = Array(Set(extractedKeywords)).sorted()
        entities = extractedEntities
    }
}
