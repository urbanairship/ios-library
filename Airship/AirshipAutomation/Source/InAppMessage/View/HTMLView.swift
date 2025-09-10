/* Copyright Airship and Contributors */

#if !os(tvOS)

import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

import Combine

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

    init(displayContent: InAppMessageDisplayContent.HTML, theme: InAppMessageTheme.HTML) {
        self.displayContent = displayContent
        self.theme = theme
    }

    var body: some View {
        let allowAspectLock = displayContent.width != nil && displayContent.height != nil && displayContent.aspectLock == true

        InAppMessageWebView(displayContent: displayContent, accessibilityLabel: "In-app web view")
            .airshipApplyIf(!theme.hideDismissIcon){
                $0.addCloseButton(
                    dismissIconResource: theme.dismissIconResource,
                    dismissButtonColor: displayContent.dismissButtonColor?.color,
                    width: theme.dismissIconWidth,
                    height: theme.dismissIconHeight,
                    onUserDismissed: {
                        environment.onUserDismissed()
                    }
                )
            }.airshipApplyIf(isModal && allowAspectLock) {
                $0.cornerRadius(displayContent.borderRadius ?? 0)
                    .aspectResize(
                        width: displayContent.width,
                        height: displayContent.height
                    )
                    .parentClampingResize(maxWidth: theme.maxWidth, maxHeight: theme.maxHeight)
                    .padding(theme.padding)
                    .addBackground(color: .airshipShadowColor)
            }.airshipApplyIf(isModal && !allowAspectLock) {
                $0.cornerRadius(displayContent.borderRadius ?? 0)
                    .parentClampingResize(
                        maxWidth: min(theme.maxWidth, (displayContent.width ?? .infinity)),
                        maxHeight: min(theme.maxHeight, (displayContent.height ?? .infinity))
                    )
                    .padding(theme.padding)
                    .addBackground(color: .airshipShadowColor)
            }.airshipApplyIf(!isModal) {
                /// Add system background color by default - clear color will be parsed by the display content if it's set
                $0.addBackground(color: displayContent.backgroundColor?.color ?? Color(.systemBackground))
            }
            .onAppear {
                self.environment.onAppear()
            }
    }

    var isModal: Bool {
        guard displayContent.forceFullscreen != true else {
            return false
        }

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

#endif
