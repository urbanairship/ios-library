/* Copyright Airship and Contributors */

import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

struct PreferenceCloseButton: View {
    internal init(dismissIconColor: Color, dismissIconResource:String, onTap: @escaping () -> ()) {
        self.dismissIconColor = dismissIconColor
        self.dismissIconResource = dismissIconResource
        self.onTap = onTap
    }

    let dismissIconColor: Color
    let dismissIconResource: String

    let onTap: () -> Void

    private let opacity: CGFloat = 0.64

    private let height: CGFloat = 24
    private let width: CGFloat = 24

    private let tappableHeight: CGFloat = 44
    private let tappableWidth: CGFloat = 44

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
            .padding()
            .clipShape(Circle()))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment:.center, spacing:0) {
                Spacer()
                dismissButtonImage
                    .opacity(opacity)
                Spacer()
            }
            .frame(width: tappableWidth, height: tappableHeight)
        }
        .accessibilityLabel("Dismiss")
    }
}

#Preview {
    PreferenceCloseButton(dismissIconColor: .primary,
                dismissIconResource: "xmark",
                onTap: {})
    .background(Color.green)
}

extension View {
    @ViewBuilder
    func addPromptBackground(theme: PreferenceCenterTheme.ContactManagement?, colorScheme: ColorScheme) -> some View {
        let color = colorScheme.airshipResolveColor(
            light: theme?.backgroundColor,
            dark: theme?.backgroundColorDark
        )

        self.background(
            BackgroundShape(
                color: color ?? PreferenceCenterDefaults.promptBackgroundColor
            )
        )
    }

    @ViewBuilder
    func addPreferenceCloseButton(
        dismissButtonColor: Color,
        dismissIconResource: String,
        contentDescription: String?,
        onUserDismissed: @escaping () -> Void
    ) -> some View {
        ZStack(alignment: .topTrailing) { // Align close button to the top trailing corner
            self.zIndex(0)
            PreferenceCloseButton(
                dismissIconColor: dismissButtonColor,
                dismissIconResource: dismissIconResource,
                onTap: onUserDismissed
            )
            .airshipApplyIf(contentDescription != nil) { view in
                view.accessibilityLabel(contentDescription!)
            }
            .zIndex(1)
        }
    }
}
