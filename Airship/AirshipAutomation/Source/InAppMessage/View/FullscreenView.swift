/* Copyright Airship and Contributors */

import SwiftUI
import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

struct FullscreenView: View, Sendable {
    @EnvironmentObject var environment: InAppMessageEnvironment
    let displayContent: InAppMessageDisplayContent.Fullscreen
    let theme: InAppMessageTheme.Fullscreen


    @ViewBuilder
    private var headerView: some View {
        if let heading = displayContent.heading {
            TextView(textInfo: heading, textTheme: self.theme.header)
                .applyAlignment(placement: displayContent.heading?.alignment ?? .left)
                .accessibilityAddTraits(.isHeader)
                .accessibilityAddTraits(.isStaticText)
        }
    }

    @ViewBuilder
    private var bodyView: some View {
        if let body = displayContent.body {
            TextView(textInfo: body, textTheme: self.theme.body)
                .applyAlignment(placement: displayContent.body?.alignment ?? .left)
                .accessibilityAddTraits(.isStaticText)
        }
    }

    @ViewBuilder
    private var mediaView: some View {
        if let media = displayContent.media {
            MediaView(mediaInfo: media, mediaTheme: self.theme.media)
        }
    }

    @ViewBuilder
    private var buttonsView: some View {
        if let buttons = displayContent.buttons, !buttons.isEmpty {
            ButtonGroup(
                layout: displayContent.buttonLayoutType ?? .stacked,
                buttons: buttons,
                theme: theme.buttons
            )
        }
    }

    @ViewBuilder
    private var footerButton: some View {
        if let footer = displayContent.footer {
            ButtonView(buttonInfo: footer)
        }
    }

    var body: some View {
            ScrollView {
                VStack(spacing:24) {
                    switch displayContent.template {
                    case .headerMediaBody:
                        headerView
                        mediaView
                        bodyView
                    case .headerBodyMedia:
                        headerView
                        bodyView
                        mediaView
                    case .mediaHeaderBody, .none:
                        mediaView.padding(.top, -theme.padding.top) /// Remove top padding when media is on top
                        headerView
                        bodyView
                    }
                    buttonsView
                    footerButton
                }
                .padding(theme.padding)
                .background(Color.airshipTappableClear)
            }
            .addCloseButton(
                dismissIconResource: theme.dismissIconResource,
                dismissButtonColor: displayContent.dismissButtonColor?.color,
                width: theme.dismissIconWidth,
                height: theme.dismissIconHeight,
                onUserDismissed: {
                    environment.onUserDismissed()
                }
            )
            .addBackground(
                color: displayContent.backgroundColor?.color ?? Color.black
            )
            .onAppear {
                self.environment.onAppear()
            }
    }
}

#Preview {
    let headingText = InAppMessageTextInfo(text: "this is header text")
    let bodyText = InAppMessageTextInfo(text: "this is body text")

    let displayContent = InAppMessageDisplayContent.Fullscreen(heading: headingText, body:bodyText, buttons: [], template: .headerMediaBody)

    return FullscreenView(displayContent: displayContent, theme: InAppMessageTheme.Fullscreen.defaultTheme)
}
