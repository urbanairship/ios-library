/* Copyright Airship and Contributors */

import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

struct HTMLView: View {

#if !os(tvOS) && !os(watchOS)
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    let displayContent: InAppMessageDisplayContent.HTML
    let theme: InAppMessageTheme.HTML

    #if os(iOS)
    private var orientationChangePublisher = NotificationCenter.default
        .publisher(for: UIDevice.orientationDidChangeNotification)
        .makeConnectable()
        .autoconnect()
    #endif

    @EnvironmentObject private var environment: InAppMessageEnvironment
    @Environment(\.orientation) private var orientation


    init(displayContent: InAppMessageDisplayContent.HTML, theme: InAppMessageTheme.HTML) {
        self.displayContent = displayContent
        self.theme = theme
    }

    var body: some View {
        let allowAspectLock = displayContent.width != nil && displayContent.height != nil && displayContent.aspectLock == true

        InAppMessageWebView(displayContent: displayContent, accessibilityLabel: "In-app web view")
            .applyIf(!theme.hideDismissIcon){
                $0.addCloseButton(
                    dismissButtonColor: displayContent.dismissButtonColor?.color ?? Color.white,
                    dismissIconResource: theme.dismissIconResource,
                    circleColor: .airshipTappableClear, /// Probably should just do this everywhere and remove circleColor entirely
                    onUserDismissed: {
                        environment.onUserDismissed()
                    }
                )
            }.applyIf(isModal && allowAspectLock) {
                $0.cornerRadius(displayContent.borderRadius ?? 0)
                    .aspectResize(
                        width: displayContent.width,
                        height: displayContent.height
                    )
                    .parentClampingResize(maxWidth: theme.maxWidth, maxHeight: theme.maxHeight)
                    .padding(theme.padding)
                    .addBackground(color: .airshipShadowColor)
            }.applyIf(isModal && !allowAspectLock) {
                $0.cornerRadius(displayContent.borderRadius ?? 0)
                    .parentClampingResize(
                        maxWidth: min(theme.maxWidth, (displayContent.width ?? .infinity)),
                        maxHeight: min(theme.maxHeight, (displayContent.height ?? .infinity))
                    )
                    .padding(theme.padding)
                    .addBackground(color: .airshipShadowColor)
            }.applyIf(!isModal) {
                $0.addBackground(color: displayContent.backgroundColor?.color ?? Color.clear)
            }
            .onAppear {
                self.environment.onAppear()
            }
    }

    var isModal: Bool {
        guard displayContent.allowFullscreen == true else {
            return true
        }

        #if os(tvOS)
        return true
        #elseif os(watchOS)
        return false
        #else
        return verticalSizeClass == .regular && horizontalSizeClass == .regular
        #endif
    }

            
}

#Preview {
    let displayContent = InAppMessageDisplayContent.HTML(url: "www.airship.com")
    return HTMLView(displayContent: displayContent, theme: InAppMessageTheme.HTML.defaultTheme)
}
