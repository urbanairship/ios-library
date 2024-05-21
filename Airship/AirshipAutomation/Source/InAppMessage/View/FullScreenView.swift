/* Copyright Airship and Contributors */

import SwiftUI
import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

struct FullScreenView: View, Sendable {
    @EnvironmentObject var environment: InAppMessageEnvironment
    let displayContent: InAppMessageDisplayContent.Fullscreen

    private var padding: EdgeInsets {
        environment.theme.fullScreenTheme.additionalPadding
    }

    private var headerTheme: TextTheme {
        environment.theme.fullScreenTheme.headerTheme
    }

    private var bodyTheme: TextTheme {
        environment.theme.fullScreenTheme.bodyTheme
    }

    private var mediaTheme: MediaTheme {
        environment.theme.fullScreenTheme.mediaTheme
    }

    private var dismissIconResource: String {
        environment.theme.fullScreenTheme.dismissIconResource
    }

    @ViewBuilder
    private var headerView: some View {
        if let heading = displayContent.heading {
            TextView(textInfo: heading, textTheme:headerTheme)
                .applyAlignment(placement: displayContent.heading?.alignment ?? .left)
        }
    }

    @ViewBuilder
    private var bodyView: some View {
        if let body = displayContent.body {
            TextView(textInfo: body, textTheme:bodyTheme)
                .applyAlignment(placement: displayContent.body?.alignment ?? .left)
        }
    }

    @ViewBuilder
    private var mediaView: some View {
        if let media = displayContent.media {
            MediaView(mediaInfo: media, mediaTheme: mediaTheme, imageLoader: environment.imageLoader)
                .padding(.horizontal, -mediaTheme.additionalPadding.leading)
        }
    }

    @ViewBuilder
    private var buttonsView: some View {
        if let buttons = displayContent.buttons, !buttons.isEmpty {
            ButtonGroup(layout: displayContent.buttonLayoutType ?? .stacked,
                        buttons: buttons)
            .environmentObject(environment)
        }
    }

    @ViewBuilder
    private var footerButton: some View {
        if let footer = displayContent.footer {
            ButtonView(buttonInfo: footer)
                .frame(height:Theme.defaultFooterHeight)
                .environmentObject(environment)
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
                    case .mediaHeaderBody, .none: /// None should never be hit
                        mediaView.padding(.top, -padding.top) /// Remove top padding when media is on top
                        headerView
                        bodyView
                    }
                    buttonsView
                    footerButton
                }.padding(padding)
                    .background(Color.airshipTappableClear)
            }
            .addCloseButton(
                dismissButtonColor: displayContent.dismissButtonColor?.color ?? Color.white,
                dismissIconResource: dismissIconResource,
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

    return FullScreenView(displayContent: displayContent)
}
