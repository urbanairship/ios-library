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

    @StateObject private var timer: BannerTimer

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
        }
    }

    @ViewBuilder
    private var bodyView: some View {
        if let body = displayContent.body {
            TextView(textInfo: body, textTheme: self.theme.body)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isStaticText)
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
        self._timer = StateObject(wrappedValue: BannerTimer(duration: displayContent.duration))
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

        let body = VStack(spacing: itemSpacing) {
            contentBody
            buttonsView
        }
        .padding(.horizontal, itemSpacing)
        .addNub(
            placement: displayContent.placement ?? .bottom,
            nub: AnyView(nub),
            itemSpacing: itemSpacing
        )
        .geometryGroupCompat()

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
            .showing(isShowing: isShowing)
            .padding(theme.padding)
            .applyTransitioningPlacement(placement: displayContent.placement ?? .bottom)
            .offset(x: 0, y: swipeOffset)
            .simultaneousGesture(swipeGesture)
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
}

fileprivate extension View {
    @ViewBuilder
    func geometryGroupCompat() -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) {
            self.geometryGroup()
        } else {
            self.transformEffect(.identity)
        }
    }

    @ViewBuilder
    func showing(isShowing: Bool) -> some View {
        if isShowing {
            self.opacity(1)
        } else {
            self.hidden().opacity(0)
        }
    }

    @ViewBuilder
    func addNub(
        placement: InAppMessageDisplayContent.Banner.Placement,
        nub: AnyView,
        itemSpacing: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            switch(placement) {
            case .top:
                self
                nub.padding(.vertical, itemSpacing / 2)
            default:
                nub.padding(.vertical, itemSpacing / 2)
                self
            }
        }
    }

    @ViewBuilder
    func applyTransitioningPlacement(
        placement: InAppMessageDisplayContent.Banner.Placement
    ) -> some View {
        switch placement {
        case .top:
            VStack {
                self.applyTransition(placement: .top)
                Spacer()
            }
        default:
            VStack {
                Spacer()
                self.applyTransition(placement: .bottom)
            }
        }
    }

    @ViewBuilder
    private func applyTransition(
        placement: InAppMessageDisplayContent.Banner.Placement
    ) -> some View {
        switch(placement) {
        case .top:
            self.transition(
                .asymmetric(
                    insertion: .move(edge: .top),
                    removal: .move(edge: .top).combined(with: .opacity)
                )
            )
        default:
            self.transition(
                .asymmetric(
                    insertion: .move(edge: .bottom),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                )
            )
        }
    }
}

fileprivate struct InAppMessageCustomOpacityButtonStyle: ButtonStyle {
    let pressedOpacity: Double
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? pressedOpacity : 1.0)
    }
}



@MainActor
fileprivate final class BannerTimer: ObservableObject {
    private static let tick: TimeInterval = 0.1
    private var elapsedTime: TimeInterval = 0
    private let duration: TimeInterval?

    private var isStarted: Bool = false
    private var task: Task<Void, any Error>?
    var isPaused: Bool = false

    @Published private(set) var isExpired: Bool = false

    init(duration: TimeInterval?) {
        self.duration = duration
    }

    func onAppear() {
        guard !isStarted, !isExpired, let duration else {
            return
        }

        self.isStarted = true

        self.task = Task { @MainActor [weak self] in
            while self?.isExpired == false, self?.isStarted == true {
                try await Task.sleep(nanoseconds: UInt64(Self.tick * 1_000_000_000))
                guard let self, self.isStarted, !Task.isCancelled else { return }

                if !self.isPaused {
                    self.elapsedTime += Self.tick
                    if self.elapsedTime >= duration {
                        self.isExpired = true
                        self.task?.cancel()
                    }
                }
            }
        }
    }

    func onDisappear() {
        isStarted = false
        task?.cancel()
    }
}
