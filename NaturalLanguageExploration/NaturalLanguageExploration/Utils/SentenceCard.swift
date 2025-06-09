//
//  SentenceCard.swift
//  NaturalLanguageExploration
//
//  Created by M Naufal Badruttamam on 09/06/25.
//

import SwiftUI

struct SentenceCard: View {
    let text: String
    let sentiment: Double

    var body: some View {
        HStack {
            Rectangle()
                .fill(sentimentColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.body)

                HStack {
                    Text(sentimentLabel)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(sentimentColor)

                    Spacer()

                    Text("\(Int(abs(sentiment) * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.leading, 8)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    var sentimentColor: Color {
        sentiment > 0.1 ? .green : sentiment < -0.1 ? .red : .orange
    }

    var sentimentLabel: String {
        sentiment > 0.1 ? "Positive" : sentiment < -0.1 ? "Negative" : "Neutral"
    }
}
