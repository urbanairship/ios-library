/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

#if !os(watchOS)

class InAppMessageHostingController<Content> : UIHostingController<Content> where Content : View {
    var onDismiss: (() -> Void)?

    override init(rootView: Content) {
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
        onDismiss = nil
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


class InAppMessageBannerViewController: InAppMessageHostingController<InAppMessageBannerView> {

    private var centerXConstraint: NSLayoutConstraint?
    private var topConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var widthConstraint: NSLayoutConstraint?

    private let bannerConstraints: InAppMessageBannerConstraints
    private let placement: InAppMessageDisplayContent.Banner.Placement?

    init(rootView: InAppMessageBannerView,
         placement: InAppMessageDisplayContent.Banner.Placement?,
         bannerConstraints: InAppMessageBannerConstraints) {
        self.bannerConstraints = bannerConstraints
        self.placement = placement
        super.init(rootView: rootView)
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        createBannerConstraints()
        handleBannerConstraints()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        handleBannerConstraints()
    }

    func createBannerConstraints() {
        self.view.translatesAutoresizingMaskIntoConstraints = false
        if let rootController = self.parent {

            centerXConstraint = self.view.centerXAnchor.constraint(equalTo: rootController.view.centerXAnchor)
            topConstraint = self.view.topAnchor.constraint(equalTo: rootController.view.topAnchor)
            bottomConstraint = self.view.bottomAnchor.constraint(equalTo: rootController.view.bottomAnchor)

            heightConstraint = self.view.heightAnchor.constraint(equalToConstant: self.bannerConstraints.size.height)
            widthConstraint = self.view.widthAnchor.constraint(equalToConstant: self.bannerConstraints.size.width)
        }
    }

    func handleBannerConstraints() {
        if let heightConstraint = heightConstraint, let widthConstraint = widthConstraint, let centerXConstraint = centerXConstraint {
            centerXConstraint.isActive = true
            heightConstraint.isActive = true
            widthConstraint.isActive = true
        }

        if let topConstraint = topConstraint, let bottomConstraint = bottomConstraint, let placement = self.placement {
            switch placement {
            case .top:
                topConstraint.isActive = true
                bottomConstraint.isActive = false
                heightConstraint?.constant = self.bannerConstraints.size.height + self.view.safeAreaInsets.top

            case .bottom:
                topConstraint.isActive = false
                bottomConstraint.isActive = true

                heightConstraint?.constant = self.bannerConstraints.size.height + self.view.safeAreaInsets.bottom
            }
        }

        widthConstraint?.constant = self.bannerConstraints.size.width

        self.view.layoutIfNeeded()
    }
}

class InAppMessageBannerConstraints: ObservableObject {
    @Published
    var size: CGSize

    init(size: CGSize) {
        self.size = size
    }
}
