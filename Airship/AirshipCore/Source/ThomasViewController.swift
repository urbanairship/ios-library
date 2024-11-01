/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

#if !os(watchOS)

@available(iOS 13.0.0, tvOS 13.0, *)
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


@available(iOS 13.0.0, tvOS 13.0, *)
class ThomasBannerViewController: ThomasViewController<BannerView> {
    
    private var centerXConstraint: NSLayoutConstraint?
    private var topConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var widthConstraint: NSLayoutConstraint?

    private let thomasBannerConstraints: ThomasBannerConstraints
    private weak var window: UIWindow?

    init(window: UIWindow, rootView: BannerView, options: ThomasViewControllerOptions, constraints: ThomasBannerConstraints) {
        self.thomasBannerConstraints = constraints
        self.window = window
        super.init(rootView: rootView, options: options)
    }
    
    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        createBannerConstraints()
        handleBannerConstraints()

        if UIAccessibility.isVoiceOverRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + BannerView.animationInDuration) {
                UIAccessibility.post(notification: .screenChanged, argument: self)
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        handleBannerConstraints()
        if let size = self.parent?.view.bounds.size, size != self.thomasBannerConstraints.size {
            self.thomasBannerConstraints.size = size
        }
    }
    
    func createBannerConstraints () {
        self.view.translatesAutoresizingMaskIntoConstraints = false
        if let window = self.window {
            centerXConstraint = self.view.centerXAnchor.constraint(equalTo: window.centerXAnchor)
            topConstraint = self.view.topAnchor.constraint(equalTo: window.topAnchor)
            bottomConstraint = self.view.bottomAnchor.constraint(equalTo: window.bottomAnchor)
            heightConstraint = self.view.heightAnchor.constraint(equalToConstant: self.options.bannerSize?.height ?? 0.0)
            widthConstraint = self.view.widthAnchor.constraint(equalToConstant: self.options.bannerSize?.width ?? 0.0)
        }
    }
    
    func handleBannerConstraints() {
        if let heightConstraint = heightConstraint, let widthConstraint = widthConstraint, let centerXConstraint = centerXConstraint {
            centerXConstraint.isActive = true
            heightConstraint.isActive = true
            widthConstraint.isActive = true
        }
        
        if let topConstraint = topConstraint, let bottomConstraint = bottomConstraint, let placement = self.options.bannerPlacement {
            
            switch placement.position {
            case .top:
                topConstraint.isActive = true
                bottomConstraint.isActive = false
            case .bottom:
                topConstraint.isActive = false
                bottomConstraint.isActive = true
            }
        }
        
        if let bannerSize = self.options.bannerSize {
            heightConstraint?.constant = bannerSize.height
            widthConstraint?.constant = bannerSize.width
        }
        self.view.layoutIfNeeded()
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
class ThomasModalViewController : ThomasViewController<ModalView> {

    override init(rootView: ModalView, options: ThomasViewControllerOptions) {
        super.init(rootView: rootView, options: options)
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#endif

@available(iOS 13.0.0, tvOS 13.0, *)
class ThomasViewControllerOptions {
    var orientation: Orientation?
    var bannerPlacement: BannerPlacement?
    var bannerSize: CGSize?
}


@MainActor
class ThomasBannerConstraints: ObservableObject {
    @Published
    var size: CGSize

    init(size: CGSize) {
        self.size = size
    }
}
