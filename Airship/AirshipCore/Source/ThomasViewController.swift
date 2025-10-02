/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

#if !os(watchOS)

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
    private weak var window: UIWindow?

    init(window: UIWindow,
        rootView: BannerView,
        position: ThomasPresentationInfo.Banner.Position,
        options: ThomasViewControllerOptions,
        constraints: ThomasBannerConstraints
    ) {
        self.thomasBannerConstraints = constraints
        self.window = window
        self.position = position
        super.init(rootView: rootView, options: options)
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        createBannerConstraints()
        handleBannerConstraints(size: self.thomasBannerConstraints.size)

        if UIAccessibility.isVoiceOverRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + BannerView.animationInOutDuration) {
                UIAccessibility.post(notification: .screenChanged, argument: self)
            }
        }

        subscription = thomasBannerConstraints.$size.sink { [weak self] size in
            self?.handleBannerConstraints(size: size)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        subscription?.cancel()
        super.viewWillDisappear(animated)
    }

    func createBannerConstraints() {
        self.view.translatesAutoresizingMaskIntoConstraints = false
        if let window = self.window {
            centerXConstraint = self.view.centerXAnchor.constraint(equalTo: window.centerXAnchor)
            topConstraint = self.view.topAnchor.constraint(equalTo: window.topAnchor)
            bottomConstraint = self.view.bottomAnchor.constraint(equalTo: window.bottomAnchor)

            heightConstraint = self.view.heightAnchor.constraint(equalToConstant: self.thomasBannerConstraints.size.height)
            widthConstraint = self.view.widthAnchor.constraint(equalToConstant: self.thomasBannerConstraints.size.width)
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

        self.view.layoutIfNeeded()
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
    var size: CGSize

    init(size: CGSize) {
        self.size = size
    }
}
