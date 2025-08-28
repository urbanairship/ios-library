/* Copyright Airship and Contributors */


import SwiftUI

#if !os(watchOS)

class InAppMessageHostingController<Content> : UIHostingController<Content> where Content : View {
    var onDismiss: (() -> Void)?

    override init(rootView: Content) {
        super.init(rootView: rootView)
        self.view.backgroundColor = .clear
    }

    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dismiss()
    }

    private func dismiss() {
        self.onDismiss?()
        onDismiss = nil
    }

    override func accessibilityPerformEscape() -> Bool {
        dismiss()
        return true
    }

#if !os(tvOS)
    /// Just to be explicit about what we expect from these hosting controllers
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }

    override var shouldAutorotate: Bool {
        return true
    }
#endif

}

#endif

import Combine

class InAppMessageBannerViewController: InAppMessageHostingController<InAppMessageBannerView> {

    private var centerXConstraint: NSLayoutConstraint?
    private var topConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var widthConstraint: NSLayoutConstraint?

    private let bannerConstraints: InAppMessageBannerConstraints
    private let placement: InAppMessageDisplayContent.Banner.Placement?

    private var subscription: AnyCancellable?
    private weak var window: UIWindow?

    init(window: UIWindow,
         rootView: InAppMessageBannerView,
         placement: InAppMessageDisplayContent.Banner.Placement?,
         bannerConstraints: InAppMessageBannerConstraints
    ) {
        self.bannerConstraints = bannerConstraints
        self.placement = placement
        self.window = window
        super.init(rootView: rootView)
    }

    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        createBannerConstraints()
        handleBannerConstraints(size: self.bannerConstraints.size)

        if UIAccessibility.isVoiceOverRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + InAppMessageBannerView.animationInOutDuration) {
                self.view.accessibilityViewIsModal = true
                UIAccessibility.post(notification: .screenChanged, argument: self.view)
            }
        }

        subscription = bannerConstraints.$size.sink { [weak self] size in
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

            heightConstraint = self.view.heightAnchor.constraint(equalToConstant: self.bannerConstraints.size.height)
            widthConstraint = self.view.widthAnchor.constraint(equalToConstant: self.bannerConstraints.size.width)
        }
    }

    func handleBannerConstraints(size: CGSize) {
        // Ensure view is still in window hierarchy before updating constraints
        guard self.view.window != nil else { return }

        self.centerXConstraint?.isActive = true
        self.heightConstraint?.isActive = true
        self.widthConstraint?.isActive = true
        self.widthConstraint?.constant = size.width

        switch self.placement {
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

@MainActor
class InAppMessageBannerConstraints: ObservableObject {
    @Published
    var size: CGSize

    init(size: CGSize) {
        self.size = size
    }
}
