/* Copyright Airship and Contributors */

import SwiftUI

struct KeyItem {
    var name: String
    var color: Color
}

struct KeyView: View {
    var keyItems: [KeyItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(keyItems, id: \.name) { item in
                HStack {
                    Image(systemName:"square.fill")
                        .resizable()
                        .foregroundColor(item.color)
                        .frame(width: 16, height: 16)
                    Text(item.name).font(.caption).foregroundColor(.black)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .foregroundColor(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.gray, lineWidth: 1)
                )
        )
    }
}


struct KeyViewModifier: ViewModifier {
    var keyItems: [KeyItem]

    func body(content: Content) -> some View {
        ZStack(alignment: .center) {
            content
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    KeyView(keyItems: keyItems).padding()
                }
            }
        }
    }
}

extension View {
    func addKeyView(keyItems: [KeyItem]) -> some View {
        self.modifier(KeyViewModifier(keyItems: keyItems))
    }
}

#Preview {
    KeyView(keyItems: [
        KeyItem(name: "Unbounded scroll view", color: .red),
        KeyItem(name: "Embedded view", color: .green),
        KeyItem(name: "Embedded view frame", color: .blue)
    ])
}
