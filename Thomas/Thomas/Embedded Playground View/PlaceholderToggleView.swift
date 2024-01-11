/* Copyright Urban Airship and Contributors */

import Foundation
import SwiftUI

struct EmbeddedToggleModifier: ViewModifier {
    @Binding var state:Bool

    func body(content: Content) -> some View {
        ZStack(alignment: .center) {
            content
            VStack {
                Spacer()
                HStack {
                    Button {
                        withAnimation {
                            state.toggle()
                        }
                    } label: {
                        HStack(spacing:4) {
                            Image(systemName: state ? "square.fill" : "square")
                                .resizable()
                                .frame(width: 16, height: 16)
                            Text("Toggle placeholder").font(.caption).foregroundColor(.black)
                        }.padding(8)
                    }.background(
                        RoundedRectangle(cornerRadius: 2)
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                    ).padding()
                    Spacer()
                }
            }
        }
    }
}

extension View {
    func addPlaceholderToggle(state:Binding<Bool>) -> some View {
        self.modifier(EmbeddedToggleModifier(state:state))
    }
}

