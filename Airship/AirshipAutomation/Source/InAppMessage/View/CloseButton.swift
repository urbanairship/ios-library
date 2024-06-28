/* Copyright Airship and Contributors */

import SwiftUI

struct CloseButton: View {
    internal init(
        dismissIconImage: Image,
        dismissIconColor: Color,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        onTap: @escaping () -> ()
    ) {
        self.dismissIconColor = dismissIconColor
        self.dismissIconImage = dismissIconImage
        self.width = width ?? 12
        self.height = height ?? 12
        self.onTap = onTap
    }

    let dismissIconColor: Color
    let dismissIconImage: Image

    let onTap: () -> ()

    private let opacity: CGFloat = 0.25
    private let defaultPadding: CGFloat = 24

    private let height: CGFloat
    private let width: CGFloat

    private let tappableHeight: CGFloat = 44
    private let tappableWidth: CGFloat = 44

    /// Check bundle and system for resource name
    /// If system image assume it's an icon and add a circular background
    @ViewBuilder
    private var dismissButtonImage: some View {
        dismissIconImage
            .foregroundColor(dismissIconColor)
            .frame(width: width, height: height)
            .padding(8)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .center, spacing: 0) {
                Spacer()
                dismissButtonImage
                Spacer()
            }
        }
        .frame(
            width: max(tappableWidth, width),
            height: max(tappableHeight, height)
        )
            .accessibilityLabel("Dismiss")
    }
}

#Preview {
    CloseButton(dismissIconImage: Image(systemName: "xmark"),
                dismissIconColor: .white,
                onTap: {})
    .background(Color.green)
}
