/* Copyright Airship and Contributors */

import SwiftUI

struct CloseButton: View {
    internal init(dismissIconColor: Color, dismissIconResource:String, circleColor: Color? = nil, onTap: @escaping () -> ()) {
        self.dismissIconColor = dismissIconColor
        self.circleColor = circleColor ?? Color.gray.opacity(opacity)
        self.dismissIconResource = dismissIconResource
        self.onTap = onTap
    }

    let dismissIconColor: Color
    let dismissIconResource: String

    let circleColor: Color

    let onTap: () -> ()

    private let opacity: CGFloat = 0.25
    private let defaultPadding: CGFloat = 24

    private let height: CGFloat = 24
    private let width: CGFloat = 24

    private let tappableHeight: CGFloat = 48
    private let tappableWidth: CGFloat = 48

    private func imageExistsInBundle(name: String) -> Bool {
        return UIImage(named: name) != nil
    }

    /// Check bundle and system for resource name
    /// If system image assume it's an icon and add a circular background
    @ViewBuilder
    private var dismissButtonImage: some View {
        imageExistsInBundle(name: dismissIconResource) ?
        AnyView(Image(dismissIconResource)
            .resizable()
            .frame(width: width/2, height: height/2)) :
        AnyView(Image(systemName: dismissIconResource)
            .resizable()
            .frame(width: width/2, height: height/2)
            .foregroundColor(dismissIconColor)
            .padding(8)
            .background(circleColor)
            .clipShape(Circle()))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment:.center, spacing:0) {
                Spacer()
                dismissButtonImage
                Spacer()
            }
        }.frame(width: tappableWidth, height: tappableHeight)
            .accessibilityLabel("Dismiss")
    }
}

#Preview {
    CloseButton(dismissIconColor: .white,
                dismissIconResource: "xmark",
                circleColor: .red,
                onTap: {})
    .background(Color.green)
}
