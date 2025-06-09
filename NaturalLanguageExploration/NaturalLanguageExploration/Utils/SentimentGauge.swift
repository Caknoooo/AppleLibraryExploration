//
//  SentimentGauge.swift
//  NaturalLanguageExploration
//
//  Created by M Naufal Badruttamam on 09/06/25.
//
import SwiftUI

struct SentimentGauge: View {
    let sentiment: Double

    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(abs(sentiment)))
                    .stroke(sentimentColor, lineWidth: 8)
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack {
                    Text(sentimentLabel)
                        .font(.headline)
                        .fontWeight(.bold)

                    Text("\(Int(abs(sentiment) * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text("Overall Sentiment")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    var sentimentColor: Color {
        sentiment > 0.1 ? .green : sentiment < -0.1 ? .red : .orange
    }

    var sentimentLabel: String {
        sentiment > 0.1 ? "Positive" : sentiment < -0.1 ? "Negative" : "Neutral"
    }
}
