//
//  FlowLayout.swift
//  NaturalLanguageExploration
//
//  Created by M Naufal Badruttamam on 09/06/25.
//

import SwiftUI

struct FlowLayout: View {
    let items: [String]
    let content: (String) -> AnyView

    init(
        _ items: [String],
        @ViewBuilder content: @escaping (String) -> some View
    ) {
        self.items = items
        self.content = { item in AnyView(content(item)) }
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(Array(stride(from: 0, to: items.count, by: 3)), id: \.self)
            { index in
                HStack {
                    ForEach(index..<min(index + 3, items.count), id: \.self) {
                        itemIndex in
                        content(items[itemIndex])
                    }
                    Spacer()
                }
            }
        }
    }
}
