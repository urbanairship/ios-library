/* Copyright Airship and Contributors */

import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

struct HTMLView: View {
    @EnvironmentObject var environment: InAppMessageEnvironment
    let displayContent: InAppMessageDisplayContent.HTML

    @Environment(\.orientation) var orientation

    private var orientationChangePublisher = NotificationCenter.default
        .publisher(for: UIDevice.orientationDidChangeNotification)
        .makeConnectable()
        .autoconnect()

    init(displayContent: InAppMessageDisplayContent.HTML) {
        self.displayContent = displayContent
    }

    private var additionalPadding: EdgeInsets {
        environment.theme.htmlTheme.additionalPadding
    }

    private var dismissIconResource: String {
        environment.theme.htmlTheme.dismissIconResource
    }

    private var hideDismissIcon: Bool {
        environment.theme.htmlTheme.hideDismissIcon
    }

    var body: some View {
        let isModal = displayContent.width != nil || displayContent.height != nil

        InAppMessageWebView(displayContent: displayContent, accessibilityLabel: "In-app web view")
            .applyIf(!hideDismissIcon){
                $0.addCloseButton(dismissButtonColor: displayContent.dismissButtonColor?.color ?? Color.white,
                                  dismissIconResource: dismissIconResource,
                                  circleColor: .tappableClear, /// Probably should just do this everywhere and remove circleColor entirely
                                  onUserDismissed: { environment.onUserDismissed() })
            }.applyIf(isModal) {
                $0.cornerRadius(displayContent.borderRadius ?? 0)
                    .aspectResize(width:displayContent.width, height:displayContent.height)
                    .padding(additionalPadding)
                    .addBackground(color: .shadowColor)
            }.applyIf(!isModal) {
                $0.padding(additionalPadding)
                    .padding(-24) /// Undo default padding when in fullscreen
                    .addBackground(color: displayContent.backgroundColor?.color ?? Color.black)
            }
    }
}

#Preview {
    let displayContent = InAppMessageDisplayContent.HTML(url: "www.airship.com")
    return HTMLView(displayContent: displayContent)
}

