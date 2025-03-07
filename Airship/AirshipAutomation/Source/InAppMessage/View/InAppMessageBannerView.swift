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
    @State private var isShowing: Bool = false
    @State private var swipeOffset: CGFloat = 0
    @State private var isButtonTapsDisabled: Bool = false

    @StateObject var timer: AirshipObservableTimer

    var theme: InAppMessageTheme.Banner
    var onDismiss: () -> Void

    private let displayContent: InAppMessageDisplayContent.Banner
    private static let mediaMaxWidth: CGFloat = 120
    private static let mediaMinHeight: CGFloat = 88
    private static let mediaMaxHeight: CGFloat = 480
    static let animationInOutDuration = 0.2


    @ViewBuilder
    private var headerView: some View {
        if let heading = displayContent.heading {
            TextView(textInfo: heading, textTheme: self.theme.header)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityAddTraits(.isStaticText)
                .applyAlignment(placement: heading.alignment ?? .left)
        }
    }

    @ViewBuilder
    private var bodyView: some View {
        if let body = displayContent.body {
            TextView(textInfo: body, textTheme: self.theme.body)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isStaticText)
                .applyAlignment(placement: body.alignment ?? .left)
        }
    }

    @ViewBuilder
    private var mediaView: some View {
        if let media = displayContent.media {
            MediaView(
                mediaInfo: media,
                mediaTheme: self.theme.media
            )
            .padding(.horizontal, -theme.media.padding.leading)
            .frame(
                maxWidth: Self.mediaMaxWidth,
                minHeight: Self.mediaMinHeight,
                maxHeight: Self.mediaMaxHeight
            )
            .fixedSize(horizontal: false, vertical: true)
        }

    }

    @ViewBuilder
    private var buttonsView: some View {
        if let buttons = displayContent.buttons, !buttons.isEmpty {
            ButtonGroup(
                isDisabled: $isButtonTapsDisabled,
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

    init(
        environment:InAppMessageEnvironment,
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
        self._timer = StateObject(wrappedValue: AirshipObservableTimer(duration: displayContent.duration))
    }

    @ViewBuilder
    private var contentBody: some View {
        switch displayContent.template {
        case .mediaLeft, .none:
            HStack(alignment: .top, spacing: 16) {
                mediaView
                VStack(alignment: .center, spacing: 16) {
                    headerView
                    bodyView
                }
            }
        case .mediaRight:
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .center, spacing: 16) {
                    headerView
                    bodyView
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

        let body = VStack(spacing: itemSpacing) {
            contentBody
            buttonsView
        }
        .padding(.horizontal, itemSpacing)
        .airshipAddNub(
            isTopPlacement: displayContent.placement == .top,
            nub: AnyView(nub),
            itemSpacing: itemSpacing
        )
        .airshipGeometryGroupCompat()

        if let actions = displayContent.actions {
            Button(
                action: {
                    if (!self.isButtonTapsDisabled) {
                        environment.onUserDismissed()
                        environment.runActions(actions: actions)
                    }
                },
                label: {
                    body.background(Color.airshipTappableClear)
                }
            ).buttonStyle(
                InAppMessageCustomOpacityButtonStyle(pressedOpacity: theme.tapOpacity)
            )
        } else {
            body
        }
    }

    private func setShowing(state:Bool, completion: (() -> Void)? = nil) {
        withAnimation(Animation.easeInOut(duration: InAppMessageBannerView.animationInOutDuration)) {
            self.isShowing = state
        }

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + InAppMessageBannerView.animationInOutDuration, execute: {
            completion?()
        })
    }

    private var banner: some View {
        messageBody
            .frame(maxWidth: theme.maxWidth)
            .background(
                GeometryReader(content: { contentMetrics -> Color in
                    let size = contentMetrics.size
                    DispatchQueue.main.async {
                        if self.lastSize != size {
                            self.bannerConstraints.size = size
                            self.lastSize = size
                        }
                    }
                    return Color.airshipTappableClear
                })
            )
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
            .showing(isShowing: isShowing)
            .padding(theme.padding)
            .airshipApplyTransitioningPlacement(isTopPlacement: displayContent.placement == .top)
            .offset(x: 0, y: swipeOffset)
#if !os(tvOS)
            .simultaneousGesture(swipeGesture)
#endif
            .onAppear {
                setShowing(state: true)
                timer.onAppear()
                self.environment.onAppear()
            }
            .onDisappear {
                self.timer.onDisappear()
            }
            .airshipOnChangeOf(swipeOffset) { value in
                self.isButtonTapsDisabled = value != 0
                self.timer.isPaused = value != 0
            }
            .airshipOnChangeOf(environment.isDismissed) { _ in
                setShowing(state: false) {
                    onDismiss()
                }
            }
            .onReceive(timer.$isExpired) { expired in
                if (expired) {
                    self.environment.onUserDismissed()
                }
            }
            .frame(width: self.width)
    }

    var width: CGFloat {
#if os(visionOS)
        min(1280, theme.maxWidth)
#else
        min(UIScreen.main.bounds.size.width, theme.maxWidth)
#endif
    }

    var body: some View {
        InAppMessageRootView(inAppMessageEnvironment: environment) { 
            banner
        }
    }

#if !os(tvOS)
    private var swipeGesture: some Gesture {
        let minSwipeDistance: CGFloat = if self.bannerConstraints.size.height > 0 {
            min(100.0,  self.bannerConstraints.size.height * 0.5)
        } else {
            100.0
        }

        let placement = displayContent.placement ?? .bottom

        return DragGesture(minimumDistance: 10)
            .onChanged { gesture in
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 20)) {
                    let offset = gesture.translation.height

                    let upwardSwipeTopPlacement = (placement == .top && offset < 0)
                    let downwardSwipeBottomPlacement = (placement == .bottom && offset > 0)

                    if upwardSwipeTopPlacement || downwardSwipeBottomPlacement {
                        self.swipeOffset = gesture.translation.height
                    }
                }
            }
            .onEnded { gesture in
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 20)) {
                    let offset = gesture.translation.height
                    swipeOffset = offset

                    let upwardSwipeTopPlacement = (placement == .top && offset < -minSwipeDistance)
                    let downwardSwipeBottomPlacement = (placement == .bottom && offset > minSwipeDistance)

                    if upwardSwipeTopPlacement || downwardSwipeBottomPlacement {
                        self.environment.onUserDismissed()
                    } else {
                        /// Return to origin and do nothing
                        self.swipeOffset = 0
                    }
                }
            }
    }
#endif
}

fileprivate struct InAppMessageCustomOpacityButtonStyle: ButtonStyle {
    let pressedOpacity: Double
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? pressedOpacity : 1.0)
    }
}
