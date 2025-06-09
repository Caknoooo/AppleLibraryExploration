//
//  LanguageRow.swift
//  NaturalLanguageExploration
//
//  Created by M Naufal Badruttamam on 09/06/25.
//

import SwiftUI

struct LanguageRow: View {
    let language: String
    let code: String
    let confidence: Double
    let isPrimary: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(language)
                    .font(isPrimary ? .headline : .body)
                    .fontWeight(isPrimary ? .bold : .regular)

                Text(code.uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("\(Int(confidence * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)

                ProgressView(value: confidence)
                    .frame(width: 60)
            }
        }
        .padding()
        .background(
            isPrimary ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05)
        )
        .cornerRadius(8)
        .padding(.horizontal)
    }
}
