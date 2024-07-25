/* Copyright Airship and Contributors */

import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppMessageBannerView: View {
    @ObservedObject
    var environment: InAppMessageEnvironment

    /// Used to transmit self sizing info to UIKit host
    @ObservedObject
    var bannerConstraints: InAppMessageBannerConstraints
    /// A state variable to prevent endless size refreshing
    @State private var lastSize: CGSize?

    @State var isShowing: Bool = false
    @State var isPressed: Bool = false /// Tracks state of current touch down
    @State var messageBodyOpacity: CGFloat = 1
    @State var swipeOffset: CGFloat = 0

    var theme: InAppMessageTheme.Banner

    var onDismiss: () -> Void

    private let displayContent: InAppMessageDisplayContent.Banner

    private var mediaMaxWidth: CGFloat = 120

    private var mediaMinHeight: CGFloat = 88
    private var mediaMaxHeight: CGFloat = 480

    static let animationInOutDuration = 0.2

    @ViewBuilder
    private var headerView: some View {
        if let heading = displayContent.heading {
            TextView(textInfo: heading, textTheme: self.theme.header)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var bodyView: some View {
        if let body = displayContent.body {
            TextView(textInfo: body, textTheme: self.theme.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var mediaView: some View {
        if let media = displayContent.media {
            MediaView(mediaInfo: media, mediaTheme: self.theme.media, imageLoader: environment.imageLoader)
                .padding(.horizontal, -theme.media.padding.leading)
                .frame(
                    maxWidth: mediaMaxWidth,
                    minHeight: mediaMinHeight,
                    maxHeight: mediaMaxHeight
                )
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var buttonsView: some View {
        if let buttons = displayContent.buttons, !buttons.isEmpty {
            ButtonGroup(
                layout: displayContent.buttonLayoutType ?? .stacked,
                buttons: buttons,
                theme: self.theme.buttons
            )
        }
    }

    #if os(iOS)
    private var orientationChangePublisher = NotificationCenter.default
        .publisher(for: UIDevice.orientationDidChangeNotification)
        .makeConnectable()
        .autoconnect()
    #endif

    init(environment:InAppMessageEnvironment,
         displayContent: InAppMessageDisplayContent.Banner,
         bannerConstraints: InAppMessageBannerConstraints,
         theme: InAppMessageTheme.Banner,
         onDismiss: @escaping () -> Void
    ) {
        self.displayContent = displayContent
        self.environment = environment
        self.bannerConstraints = bannerConstraints
        self.theme = theme
        self.onDismiss = onDismiss
    }

    @ViewBuilder
    private var contentBody: some View {
        switch displayContent.template {
        case .mediaLeft, .none:
            HStack(alignment: .top, spacing: 16) {
                mediaView
                VStack(alignment: .center, spacing: 16) {
                    headerView.applyAlignment(placement: displayContent.heading?.alignment ?? .left)
                    bodyView.applyAlignment(placement: displayContent.body?.alignment ?? .left)
                }
            }
        case .mediaRight:
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .center, spacing: 16) {
                    headerView.applyAlignment(placement: displayContent.heading?.alignment ?? .left)
                    bodyView.applyAlignment(placement: displayContent.body?.alignment ?? .left)
                }
                mediaView
            }
        }
    }

    @ViewBuilder
    private var nub: some View {
        let tabHeight: CGFloat = 4
        let tabWidth: CGFloat = 36
        let tabColor:Color = displayContent.dismissButtonColor?.color ?? Color.black.opacity(0.42)

        Capsule()
            .frame(width: tabWidth, height: tabHeight)
            .foregroundColor(tabColor)
    }

    @ViewBuilder
    private var messageBody: some View {
        let itemSpacing: CGFloat = 16

        VStack(spacing:itemSpacing) {
            if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) {
                contentBody.geometryGroup()
            } else {
                contentBody.transformEffect(.identity)
            }

            buttonsView
        }
        .padding([.top, .horizontal], itemSpacing)
        .addNub(
            placement: displayContent.placement ?? .bottom,
            nub: AnyView(nub),
            itemSpacing: itemSpacing
        )
    }

    private func setShowing(state:Bool, completion: (() -> Void)? = nil) {
        withAnimation(Animation.easeInOut(duration: InAppMessageBannerView.animationInOutDuration)) {
            self.isShowing = state
        }

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + InAppMessageBannerView.animationInOutDuration, execute: {
            completion?()
        })
    }

    private func bannerOnTapAction() {
        if let actions = displayContent.actions {
            environment.onUserDismissed()
            environment.runActions(actions: actions)
        }
    }

    private var banner: some View {
        messageBody
            .showing(isShowing: isShowing)
            .frame(maxWidth: theme.maxWidth)
            .background(
                (displayContent.backgroundColor?.color ?? Color.white)
                    .cornerRadius(displayContent.borderRadius ?? 0)
                    .edgesIgnoringSafeArea(displayContent.placement == .top ? .top : .bottom)
                    .shadow(
                        color: theme.shadow.color,
                        radius: theme.shadow.radius,
                        x: theme.shadow.xOffset,
                        y: theme.shadow.yOffset
                    )
            )
            .background(
                GeometryReader(content: { contentMetrics -> Color in
                    let size = contentMetrics.size
                    DispatchQueue.main.async {
                        if self.bannerConstraints.size != lastSize {
                            self.bannerConstraints.size = size
                            self.lastSize = size
                        }
                    }
                    return Color.airshipTappableClear
                })
            )
            .padding(theme.padding)
            .applyTransitioningPlacement(placement: displayContent.placement ?? .bottom)
            .addTapAndSwipeDismiss(
                placement: displayContent.placement ?? .bottom,
                isPressed: $isPressed,
                tapAction: bannerOnTapAction,
                swipeOffset: $swipeOffset,
                onDismiss: environment.onUserDismissed
            )
            .onAppear {
                setShowing(state: true)
            }
            .airshipOnChangeOf(environment.isDismissed) { _ in
                setShowing(state: false) {
                    onDismiss()
                }
            }
            .onAppear {
                self.environment.onAppear()
            }
    }

    var body: some View {
        InAppMessageRootView(inAppMessageEnvironment: environment) { orientation in
            #if os(visionOS)
            banner.frame(width: min(1280, theme.maxWidth))
            #else
            banner.frame(width: min(UIScreen.main.bounds.size.width, theme.maxWidth))
            #endif
        }.opacity(isPressed && displayContent.actions != nil ? theme.tapOpacity : 1)
    }
}
