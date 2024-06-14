/* Copyright Airship and Contributors */

import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppMessageModalView: View {
    @EnvironmentObject var environment: InAppMessageEnvironment
    @Environment(\.orientation) var orientation

#if !os(tvOS) && !os(watchOS)
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
    
    let displayContent: InAppMessageDisplayContent.Modal
    let theme: InAppMessageTheme.Modal

    @State
    private var scrollViewContentSize: CGSize = .zero

    @ViewBuilder
    private var headerView: some View {
        if let heading = displayContent.heading {
            TextView(textInfo: heading, textTheme: theme.header)
                .applyAlignment(placement: displayContent.heading?.alignment ?? .left)
        }
    }

    @ViewBuilder
    private var bodyView: some View {
        if let body = displayContent.body {
            TextView(textInfo: body, textTheme: theme.body)
                .applyAlignment(placement: displayContent.body?.alignment ?? .left)
        }
    }

    @ViewBuilder
    private var mediaView: some View {
        if let media = displayContent.media {
            MediaView(mediaInfo: media, mediaTheme: theme.media, imageLoader: environment.imageLoader)
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

    #if os(iOS)
    private var orientationChangePublisher = NotificationCenter.default
        .publisher(for: UIDevice.orientationDidChangeNotification)
        .makeConnectable()
        .autoconnect()
    #endif

    init(displayContent: InAppMessageDisplayContent.Modal, theme: InAppMessageTheme.Modal) {
        self.displayContent = displayContent
        self.theme = theme
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing:24) {
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
                }
                .padding(.leading, theme.padding.leading)
                .padding(.trailing, theme.padding.trailing)
                .padding(.top, theme.padding.top)
                .background(
                    GeometryReader { geo -> Color in
                        DispatchQueue.main.async {
                            if scrollViewContentSize != geo.size {
                                if case .mediaHeaderBody = displayContent.template {
                                    scrollViewContentSize = CGSize(width: geo.size.width, height: geo.size.height - theme.padding.top)
                                } else {
                                    scrollViewContentSize = geo.size
                                }
                            }
                        }
                        return Color.clear
                    }
                )
            }
            .applyIf(isModal) {
                $0.frame(maxHeight: scrollViewContentSize.height)
            }
            VStack(spacing:24) {
                buttonsView
                footerButton
            }
            .padding(.leading, theme.padding.leading)
            .padding(.trailing, theme.padding.trailing)
            .padding(.bottom, theme.padding.bottom)
        }
    }

    var body: some View {
        content
        .addCloseButton(
            dismissButtonColor: displayContent.dismissButtonColor?.color ?? Color.white,
            dismissIconResource: theme.dismissIconResource,
            circleColor: .airshipTappableClear, /// Probably should just do this everywhere and remove circleColor entirely
            onUserDismissed: { environment.onUserDismissed() }
        )
        .background(displayContent.backgroundColor?.color ?? Color.black)
        .applyIf(isModal) {
            $0.cornerRadius(displayContent.borderRadius ?? 0)
            .parentClampingResize(maxWidth: theme.maxWidth, maxHeight: theme.maxHeight)
            .padding(theme.padding)
            .addBackground(color: .airshipShadowColor)
        }
        .applyIf(!isModal) {
            $0.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            self.environment.onAppear()
        }
    }

    var isModal: Bool {
        guard displayContent.allowFullscreenDisplay == true else {
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
