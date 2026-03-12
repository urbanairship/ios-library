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
        guard let orientation = options.orientation else {
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
        return self.options.orientation == nil
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


class ThomasBannerViewController: ThomasViewController<BannerView> {
    private var centerXConstraint: NSLayoutConstraint?
    private var topConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var widthConstraint: NSLayoutConstraint?

    private let thomasBannerConstraints: ThomasBannerConstraints

    private let position: ThomasPresentationInfo.Banner.Position?

    private var subscription: AnyCancellable?

    init(
        rootView: BannerView,
        position: ThomasPresentationInfo.Banner.Position,
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

        if let window = self.view.window {
            centerXConstraint = self.view.centerXAnchor.constraint(equalTo: window.centerXAnchor)
            topConstraint = self.view.topAnchor.constraint(equalTo: window.topAnchor)
            bottomConstraint = self.view.bottomAnchor.constraint(equalTo: window.bottomAnchor)
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
        self.topConstraint?.isActive = false
        self.bottomConstraint?.isActive = false

        let edgeInsets = contentPlacement.additionalEdgeInsets

        // Shift horizontal constraint by start/end margins
        // Positive leading margin shifts right, positive trailing margin shifts left
        let horizontalOffset = edgeInsets.leading - edgeInsets.trailing
        self.centerXConstraint = self.view.centerXAnchor.constraint(
            equalTo: window.centerXAnchor,
            constant: horizontalOffset
        )
        self.centerXConstraint?.isActive = true

        if contentPlacement.ignoreSafeArea {
            // Anchor to window edges when ignoring safe area, shifted by margins
            if contentPlacement.isTop {
                self.topConstraint = self.view.topAnchor.constraint(
                    equalTo: window.topAnchor,
                    constant: edgeInsets.top
                )
            } else {
                self.bottomConstraint = self.view.bottomAnchor.constraint(
                    equalTo: window.bottomAnchor,
                    constant: -edgeInsets.bottom
                )
            }
        } else {
            // Anchor to safe area layout guide when respecting safe area, shifted by margins
            if contentPlacement.isTop {
                self.topConstraint = self.view.topAnchor.constraint(
                    equalTo: window.safeAreaLayoutGuide.topAnchor,
                    constant: edgeInsets.top
                )
            } else {
                self.bottomConstraint = self.view.bottomAnchor.constraint(
                    equalTo: window.safeAreaLayoutGuide.bottomAnchor,
                    constant: -edgeInsets.bottom
                )
            }
        }

        switch self.position {
        case .top:
            self.topConstraint?.isActive = true
            self.bottomConstraint?.isActive = false

        default:
            self.topConstraint?.isActive = false
            self.bottomConstraint?.isActive = true
        }

        self.view.layoutIfNeeded()
    }
}

class ThomasModalViewController : ThomasViewController<ModalView> {

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


class ThomasBannerViewController: ThomasViewController<BannerView> {
    private var centerXConstraint: NSLayoutConstraint?
    private var topConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var widthConstraint: NSLayoutConstraint?

    private let thomasBannerConstraints: ThomasBannerConstraints

    private let position: ThomasPresentationInfo.Banner.Position?

    private var subscription: AnyCancellable?

    init(rootView: BannerView,
        position: ThomasPresentationInfo.Banner.Position,
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
            topConstraint = self.view.topAnchor.constraint(equalTo: contentView.topAnchor)
            bottomConstraint = self.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)

            heightConstraint = self.view.heightAnchor.constraint(equalToConstant: self.thomasBannerConstraints.windowSize.height)
            widthConstraint = self.view.widthAnchor.constraint(equalToConstant: self.thomasBannerConstraints.windowSize.width)
        }
    }

    func handleBannerConstraints(size: CGSize) {
        // Ensure view is still in window hierarchy before updating constraints
        guard self.view.window != nil else { return }

        self.centerXConstraint?.isActive = true
        self.heightConstraint?.isActive = true
        self.widthConstraint?.isActive = true
        self.widthConstraint?.constant = size.width

        switch self.position {
        case .top:
            self.topConstraint?.isActive = true
            self.bottomConstraint?.isActive = false
            self.heightConstraint?.constant = size.height + self.view.safeAreaInsets.top

        default:
            self.topConstraint?.isActive = false
            self.bottomConstraint?.isActive = true
            self.heightConstraint?.constant = size.height + self.view.safeAreaInsets.bottom
        }

        self.view.layoutSubtreeIfNeeded()
    }
}

class ThomasModalViewController : ThomasViewController<ModalView> {

    override init(rootView: ModalView, options: ThomasViewControllerOptions) {
        super.init(rootView: rootView, options: options)
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


#endif

class ThomasViewControllerOptions {
    var orientation: ThomasOrientation?
    var bannerPlacement: ThomasPresentationInfo.Banner.Placement?
}

@MainActor
class ThomasBannerConstraints: ObservableObject {
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
            isTop: placement.position == .top,
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
    let isTop: Bool
    let additionalEdgeInsets: EdgeInsets
    let width: Double
    let height: Double
    let ignoreSafeArea: Bool
}

