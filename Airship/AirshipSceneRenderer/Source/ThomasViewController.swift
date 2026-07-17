/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

#if !os(watchOS) && !os(macOS)

class ThomasViewController<Content> : UIHostingController<Content> where Content : View {

    var options: ThomasViewControllerOptions
    var onDismiss: (() -> Void)?
    private var scrollViewsUpdated: Bool = false

    init(rootView: Content, options: ThomasViewControllerOptions = ThomasViewControllerOptions()) {
        self.options = options
        super.init(rootView: rootView)
        self.view.backgroundColor = .clear
    }

    @objc
    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.onDismiss?()
    }

#if !os(tvOS)
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        // iPad ignores supportedInterfaceOrientations unless UIRequiresFullScreen is set,
        // so attempting to lock orientation there produces broken layouts. Allow free rotation.
        guard let orientation = options.orientation,
              UIDevice.current.userInterfaceIdiom != .pad else {
            return .all
        }

        switch orientation {
        case .portrait:
            return .portrait
        case .landscape:
            return .landscape
        }
    }

    override var shouldAutorotate: Bool {
        return self.options.orientation == nil || UIDevice.current.userInterfaceIdiom == .pad
    }
#endif

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !scrollViewsUpdated {
            updateScrollViews(view: self.view)
            scrollViewsUpdated = true
        }
    }

    override func accessibilityPerformEscape() -> Bool {
        self.onDismiss?()
        return true
    }

    func updateScrollViews(view: UIView) {
        view.subviews.forEach { subView in
            if let subView = subView as? UIScrollView {
                if (subView.bounces) {
                    subView.bounces = false
#if os(tvOS)
                    subView.panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
#endif
                }
            }

            updateScrollViews(view: subView)
        }
    }
}


final class ThomasBannerViewController: ThomasViewController<BannerView> {
    private var centerXConstraint: NSLayoutConstraint?
    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?
    private var centerYConstraint: NSLayoutConstraint?
    private var topConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var widthConstraint: NSLayoutConstraint?

    private let thomasBannerConstraints: ThomasBannerConstraints

    private var subscription: AnyCancellable?

    init(
        rootView: BannerView,
        options: ThomasViewControllerOptions,
        constraints: ThomasBannerConstraints
    ) {
        self.thomasBannerConstraints = constraints
        super.init(rootView: rootView, options: options)
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        createBannerConstraints()

        if UIAccessibility.isVoiceOverRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + BannerView.animationInOutDuration) {
                UIAccessibility.post(notification: .screenChanged, argument: self)
            }
        }

        subscription = thomasBannerConstraints.$contentPlacement.sink { [weak self] contentPlacement in
            if let contentPlacement {
                self?.handleBannerConstraints(contentPlacement: contentPlacement)
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.thomasBannerConstraints.updateWindowSize(self.view.window?.frame.size)

    }

    override func viewWillDisappear(_ animated: Bool) {
        subscription?.cancel()
        super.viewWillDisappear(animated)
    }

    func createBannerConstraints() {
        self.view.translatesAutoresizingMaskIntoConstraints = false

        if self.view.window != nil {
            // Positioning constraints are created per placement in
            // handleBannerConstraints once the content placement is known.
            heightConstraint = self.view.heightAnchor.constraint(
                equalToConstant: thomasBannerConstraints.windowSize.height
            )
            widthConstraint = self.view.widthAnchor.constraint(
                equalToConstant: thomasBannerConstraints.windowSize.width
            )
        }
    }

    private func handleBannerConstraints(contentPlacement: ContentPlacement) {
        // Ensure view is still in window hierarchy before updating constraints
        guard let window = self.view.window else { return }

        // Use content size directly - margins will be handled by positioning
        self.heightConstraint?.isActive = true
        self.widthConstraint?.isActive = true
        self.widthConstraint?.constant = contentPlacement.width
        self.heightConstraint?.constant = contentPlacement.height

        // Deactivate old constraints before creating new ones
        self.centerXConstraint?.isActive = false
        self.leadingConstraint?.isActive = false
        self.trailingConstraint?.isActive = false
        self.centerYConstraint?.isActive = false
        self.topConstraint?.isActive = false
        self.bottomConstraint?.isActive = false

        let edgeInsets = contentPlacement.additionalEdgeInsets

        // Edge-anchored axes attach to window edges when ignoring safe area,
        // otherwise to the safe area layout guide. Centered axes always anchor
        // to the window center regardless of ignore_safe_area. Margins shift
        // the anchor in all cases.
        let ignoreSafeArea = contentPlacement.ignoreSafeArea

        switch contentPlacement.position.horizontal {
        case .start:
            self.leadingConstraint = self.view.leadingAnchor.constraint(
                equalTo: ignoreSafeArea
                    ? window.leadingAnchor
                    : window.safeAreaLayoutGuide.leadingAnchor,
                constant: edgeInsets.leading
            )
            self.leadingConstraint?.isActive = true

        case .end:
            self.trailingConstraint = self.view.trailingAnchor.constraint(
                equalTo: ignoreSafeArea
                    ? window.trailingAnchor
                    : window.safeAreaLayoutGuide.trailingAnchor,
                constant: -edgeInsets.trailing
            )
            self.trailingConstraint?.isActive = true

        case .center:
            // Shift horizontal constraint by start/end margins
            // Positive leading margin shifts right, positive trailing margin shifts left
            let horizontalOffset = edgeInsets.leading - edgeInsets.trailing
            self.centerXConstraint = self.view.centerXAnchor.constraint(
                equalTo: window.centerXAnchor,
                constant: horizontalOffset
            )
            self.centerXConstraint?.isActive = true
        }

        switch contentPlacement.position.vertical {
        case .top:
            self.topConstraint = self.view.topAnchor.constraint(
                equalTo: ignoreSafeArea
                    ? window.topAnchor
                    : window.safeAreaLayoutGuide.topAnchor,
                constant: edgeInsets.top
            )
            self.topConstraint?.isActive = true

        case .bottom:
            self.bottomConstraint = self.view.bottomAnchor.constraint(
                equalTo: ignoreSafeArea
                    ? window.bottomAnchor
                    : window.safeAreaLayoutGuide.bottomAnchor,
                constant: -edgeInsets.bottom
            )
            self.bottomConstraint?.isActive = true

        case .center:
            // Shift vertical constraint by top/bottom margins
            let verticalOffset = edgeInsets.top - edgeInsets.bottom
            self.centerYConstraint = self.view.centerYAnchor.constraint(
                equalTo: window.centerYAnchor,
                constant: verticalOffset
            )
            self.centerYConstraint?.isActive = true
        }

        self.view.layoutIfNeeded()
    }
}

final class ThomasModalViewController : ThomasViewController<ModalView> {

    override init(rootView: ModalView, options: ThomasViewControllerOptions) {
        super.init(rootView: rootView, options: options)
        self.modalPresentationStyle = .currentContext
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#elseif os(macOS)

@available(iOS 13.0.0, tvOS 13.0, *)
class ThomasViewController<Content> : NSHostingController<Content> where Content : View {

    var options: ThomasViewControllerOptions
    var onDismiss: (() -> Void)?
    private var scrollViewsUpdated: Bool = false

    init(rootView: Content, options: ThomasViewControllerOptions = ThomasViewControllerOptions()) {
        self.options = options
        super.init(rootView: rootView)
        self.view.layer?.backgroundColor = NSColor.clear.cgColor
    }

    @objc
    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    override func viewWillDisappear() {
        super.viewWillDisappear()
        self.onDismiss?()
    }

}


final class ThomasBannerViewController: ThomasViewController<BannerView> {
    private var centerXConstraint: NSLayoutConstraint?
    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?
    private var centerYConstraint: NSLayoutConstraint?
    private var topConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var widthConstraint: NSLayoutConstraint?

    private let thomasBannerConstraints: ThomasBannerConstraints

    private let position: ThomasEdgePosition?

    private var subscription: AnyCancellable?

    init(rootView: BannerView,
        position: ThomasEdgePosition,
        options: ThomasViewControllerOptions,
        constraints: ThomasBannerConstraints
    ) {
        self.thomasBannerConstraints = constraints

        self.position = position
        super.init(rootView: rootView, options: options)
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        createBannerConstraints()
        handleBannerConstraints(size: self.thomasBannerConstraints.windowSize)

        let isVoiceOverRunning = AXIsProcessTrusted()
        if isVoiceOverRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + BannerView.animationInOutDuration) {
                NSAccessibility.post(element: self, notification: .layoutChanged)
            }
        }

        subscription = thomasBannerConstraints.$windowSize.sink { [weak self] size in
            self?.handleBannerConstraints(size: size)
        }
    }

    override func viewWillDisappear() {
        subscription?.cancel()
        super.viewWillDisappear()
    }

    func createBannerConstraints() {
        self.view.translatesAutoresizingMaskIntoConstraints = false
        if let contentView = self.view.window?.contentView {
            centerXConstraint = self.view.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
            leadingConstraint = self.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor)
            trailingConstraint = self.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
            centerYConstraint = self.view.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
            topConstraint = self.view.topAnchor.constraint(equalTo: contentView.topAnchor)
            bottomConstraint = self.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)

            heightConstraint = self.view.heightAnchor.constraint(equalToConstant: self.thomasBannerConstraints.windowSize.height)
            widthConstraint = self.view.widthAnchor.constraint(equalToConstant: self.thomasBannerConstraints.windowSize.width)
        }
    }

    func handleBannerConstraints(size: CGSize) {
        // Ensure view is still in window hierarchy before updating constraints
        guard self.view.window != nil else { return }

        self.heightConstraint?.isActive = true
        self.widthConstraint?.isActive = true
        self.widthConstraint?.constant = size.width

        switch self.position?.horizontal {
        case .start:
            self.leadingConstraint?.isActive = true
            self.trailingConstraint?.isActive = false
            self.centerXConstraint?.isActive = false

        case .end:
            self.leadingConstraint?.isActive = false
            self.trailingConstraint?.isActive = true
            self.centerXConstraint?.isActive = false

        default:
            self.leadingConstraint?.isActive = false
            self.trailingConstraint?.isActive = false
            self.centerXConstraint?.isActive = true
        }

        switch self.position?.vertical {
        case .top:
            self.topConstraint?.isActive = true
            self.bottomConstraint?.isActive = false
            self.centerYConstraint?.isActive = false
            self.heightConstraint?.constant = size.height + self.view.safeAreaInsets.top

        case .center:
            self.topConstraint?.isActive = false
            self.bottomConstraint?.isActive = false
            self.centerYConstraint?.isActive = true
            self.heightConstraint?.constant = size.height

        default:
            self.topConstraint?.isActive = false
            self.bottomConstraint?.isActive = true
            self.centerYConstraint?.isActive = false
            self.heightConstraint?.constant = size.height + self.view.safeAreaInsets.bottom
        }

        self.view.layoutSubtreeIfNeeded()
    }
}

final class ThomasModalViewController : ThomasViewController<ModalView> {

    override init(rootView: ModalView, options: ThomasViewControllerOptions) {
        super.init(rootView: rootView, options: options)
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


#endif

final class ThomasViewControllerOptions {
    var orientation: ThomasOrientation?
    var bannerPlacement: ThomasPresentationInfo.Banner.Placement?
}

@MainActor
final class ThomasBannerConstraints: ObservableObject {
    @Published
    fileprivate var contentPlacement: ContentPlacement?

    @Published
    private(set) var windowSize: CGSize

    init(windowSize: CGSize) {
        self.windowSize = windowSize
    }
    func updateContentSize(
        _ size: CGSize,
        constraints: ViewConstraints,
        placement: ThomasPresentationInfo.Banner.Placement
    ) {
        let width = if let width = constraints.width {
            width
        } else {
            size.width
        }

        let height = if let height = constraints.height {
            height
        } else {
            size.height
        }

        let additionalEdgeInsets = EdgeInsets(
            top: placement.margin?.top ?? 0,
            leading: placement.margin?.start ?? 0,
            bottom: placement.margin?.bottom ?? 0,
            trailing: placement.margin?.end ?? 0
        )

        let contentPlacement = ContentPlacement(
            position: placement.position,
            additionalEdgeInsets: additionalEdgeInsets,
            width: width,
            height: height,
            ignoreSafeArea: placement.ignoreSafeArea == true
        )

        if self.contentPlacement != contentPlacement {
            self.contentPlacement = contentPlacement
        }
    }

    func updateWindowSize(_ size: CGSize?) {
        if self.windowSize != size, let size {
            self.windowSize = size
        }
    }
}

fileprivate struct ContentPlacement: Sendable, Equatable {
    fileprivate let position: ThomasEdgePosition
    fileprivate let additionalEdgeInsets: EdgeInsets
    fileprivate let width: Double
    fileprivate let height: Double
    fileprivate let ignoreSafeArea: Bool
}

