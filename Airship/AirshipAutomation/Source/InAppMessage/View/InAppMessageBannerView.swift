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
    @State var messageBodyOpacity: CGFloat = 1
    @State var swipeOffset: CGFloat = 0

    var onDismiss: () -> Void

    private var padding: EdgeInsets {
        environment.theme.bannerTheme.additionalPadding
    }

    private let displayContent: InAppMessageDisplayContent.Banner

    private var messageMaxWidth: CGFloat = 480

    private var mediaMaxWidth: CGFloat = 120

    private var mediaMinHeight: CGFloat = 88
    private var mediaMaxHeight: CGFloat = 480

    private let animationInOutDuration = 0.2

    private var headerTheme: TextTheme {
        environment.theme.bannerTheme.headerTheme
    }

    private var bodyTheme: TextTheme {
        environment.theme.bannerTheme.bodyTheme
    }

    private var mediaTheme: MediaTheme {
        environment.theme.bannerTheme.mediaTheme
    }

    @ViewBuilder
    private var headerView: some View {
        let theme = environment.theme.bannerTheme

        if let heading = displayContent.heading {
            TextView(textInfo: heading, textTheme: headerTheme)
                .padding(theme.headerTheme.additionalPadding)
                .padding(headerTheme.additionalPadding)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var bodyView: some View {
        if let body = displayContent.body {
            TextView(textInfo: body, textTheme:bodyTheme)
                .applyTextTheme(headerTheme)
                .padding(bodyTheme.additionalPadding)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var mediaView: some View {
        if let media = displayContent.media {
            MediaView(mediaInfo: media, mediaTheme: mediaTheme, imageLoader: environment.imageLoader)
                .padding(.horizontal, -mediaTheme.additionalPadding.leading)
                .padding(mediaTheme.additionalPadding)
                .frame(maxWidth: mediaMaxWidth,
                       minHeight: mediaMinHeight,
                       maxHeight: mediaMaxHeight)
        }
    }

    @ViewBuilder
    private var buttonsView: some View {
        if let buttons = displayContent.buttons, let layout = displayContent.buttonLayoutType, !buttons.isEmpty {
            ButtonGroup(layout: layout,
                        buttons: buttons)
            .environmentObject(environment)
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
         onDismiss: @escaping () -> Void
    ) {
        self.displayContent = displayContent
        self.environment = environment
        self.bannerConstraints = bannerConstraints
        self.onDismiss = onDismiss
    }

    @ViewBuilder
    private var contentBody: some View {
        switch displayContent.template {
        case .mediaLeft, .none:
            HStack(alignment: .top, spacing: 16) {
                mediaView
                VStack(alignment: .center, spacing: 16) {
                    headerView.applyAlignment(placement: displayContent.heading?.alignment ?? .center)
                    bodyView.applyAlignment(placement: displayContent.body?.alignment ?? .center)
                }
            }
        case .mediaRight:
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .center, spacing: 16) {
                    headerView.applyAlignment(placement: displayContent.heading?.alignment ?? .center)
                    bodyView.applyAlignment(placement: displayContent.body?.alignment ?? .center)
                }
                mediaView
            }
        }
    }

    @ViewBuilder
    private var nub: some View {
        let tabHeight: CGFloat = 4
        let tabWidth: CGFloat = 36
        let tabColor:Color = Color.black.opacity(0.42)

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
        }.padding([.top, .horizontal], itemSpacing)
            .addNub(placement: displayContent.placement,
                    nub: AnyView(nub),
                    itemSpacing: itemSpacing)
    }

    private func setShowing(state:Bool, completion: (() -> Void)? = nil) {
        withAnimation(Animation.easeInOut(duration: animationInOutDuration)) {
            self.isShowing = state
        }

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + animationInOutDuration, execute: {
            completion?()
        })
    }

    private var banner: some View {
        messageBody
            .opacity(messageBodyOpacity)
            .showing(isShowing: isShowing)
            .frame(maxWidth: messageMaxWidth)
            .background(
                (displayContent.backgroundColor?.color ?? Color.white)
                    .cornerRadius(displayContent.borderRadius ?? 0)
                    .edgesIgnoringSafeArea(displayContent.placement == .top ? .top : .bottom)
                    .shadow(radius: 5)
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
                    return .tappableClear
                })
            )
            .padding(padding)
            .applyTransitioningPlacement(placement: displayContent.placement ?? .top)
            .addSwipeDismiss(placement: displayContent.placement ?? .top,
                             swipeOffset: $swipeOffset,
                             onDismiss: environment.onUserDismissed)
            .applyIf(displayContent.actions != nil, transform: { view in
                view.gesture(TapGesture().onEnded { value in
                    environment.onUserDismissed()
                    environment.runActions(actions: displayContent.actions)
                })
            })
            .onAppear {
                setShowing(state: true)
            }
            .airshipOnChangeOf(environment.isDismissed) { _ in
                setShowing(state:false, completion: {
                    onDismiss()
                })
            }
            .onAppear {
                self.environment.onAppear()
            }
    }

    var body: some View {
        InAppMessageRootView(inAppMessageEnvironment: environment) { orientation in
            #if os(visionOS)
            banner.frame(width: min(1280, messageMaxWidth))
            #else
            banner.frame(width: min(UIScreen.main.bounds.size.width, messageMaxWidth))
            #endif
        }
    }
}
