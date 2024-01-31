/* Copyright Airship and Contributors */

import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppMessageBannerView: View {
    @EnvironmentObject var environment: InAppMessageEnvironment

    @State var isShowing: Bool = false
    @State var messageSize: CGSize = CGSizeZero
    @State var messageBodyOpacity: CGFloat = 1
    @State var swipeOffset: CGFloat = 0

    private var padding: EdgeInsets {
        environment.theme.bannerTheme.additionalPadding
    }

    private let displayContent: InAppMessageDisplayContent.Banner

    private var messageMaxWidth: CGFloat = 480

    private let animationInOutDuration = 0.2
    
    private var mediaMaxWidth: CGFloat = 120

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
        }
    }

    @ViewBuilder
    private var bodyView: some View {
        if let body = displayContent.body {
            TextView(textInfo: body, textTheme:bodyTheme)
                .applyTextTheme(headerTheme)
                .padding(bodyTheme.additionalPadding)
        }
    }

    @ViewBuilder
    private var mediaView: some View {
        if let media = displayContent.media {
            MediaView(mediaInfo: media, mediaTheme: mediaTheme, imageLoader: environment.imageLoader)
                .padding(.horizontal, -mediaTheme.additionalPadding.leading)
                .padding(mediaTheme.additionalPadding)
                .frame(maxWidth: mediaMaxWidth)
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

    private var orientationChangePublisher = NotificationCenter.default
        .publisher(for: UIDevice.orientationDidChangeNotification)
        .makeConnectable()
        .autoconnect()

    init(displayContent: InAppMessageDisplayContent.Banner) {
        self.displayContent = displayContent
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
            contentBody
            buttonsView
        }.padding([.top, .horizontal], itemSpacing)
            .addNub(placement: displayContent.placement,
                    nub: AnyView(nub),
                    itemSpacing: itemSpacing)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func setShowing(state:Bool) {
        withAnimation(Animation.easeInOut(duration: animationInOutDuration)) {
            self.isShowing = state
        }
    }

    var body: some View {
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
                        self.messageSize = size
                    }
                    return .tappableClear
                })
            )
            .padding(padding)
            .applyTransitioningPlacement(placement: displayContent.placement ?? .top)
            .addSwipeDismiss(placement: displayContent.placement ?? .top,
                             swipeOffset: $swipeOffset,
                             onDismiss: environment.onUserDismissed)
            .gesture(TapGesture().onEnded { value in
                environment.onUserDismissed()
            })
            .onChange(of: environment.isDismissed) { _ in
                setShowing(state:!environment.isDismissed)
            }
            .onAppear {
                setShowing(state: true)
            }
    }
}
