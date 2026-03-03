/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

#if !os(watchOS)

class InAppMessageHostingController<Content> : AirshipNativeHostingController<Content> where Content : View {
    var onDismiss: (() -> Void)?

    override init(rootView: Content) {
        super.init(rootView: rootView)
#if os(macOS)
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = NSColor.clear.cgColor
#else
        self.view.backgroundColor = .clear
#endif
    }

    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

#if os(macOS)
    override func viewDidDisappear() {
        super.viewDidDisappear()
        dismiss()
    }

    // macOS escape key handling is usually done via commands or
    // overriding cancelOperation in the view hierarchy.
    override func cancelOperation(_ sender: Any?) {
        dismiss()
    }
#else
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dismiss()
    }

    override func accessibilityPerformEscape() -> Bool {
        dismiss()
        return true
    }
#endif

    private func dismiss() {
        self.onDismiss?()
        onDismiss = nil
    }


#if !os(tvOS) && !os(macOS)
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

    init(
         rootView: InAppMessageBannerView,
         placement: InAppMessageDisplayContent.Banner.Placement?,
         bannerConstraints: InAppMessageBannerConstraints
    ) {
        self.bannerConstraints = bannerConstraints
        self.placement = placement
        super.init(rootView: rootView)
    }

    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

#if os(macOS)
    override func viewDidAppear() {
        super.viewDidAppear()

        createBannerConstraints()
        handleBannerConstraints(size: self.bannerConstraints.size)

        subscription = bannerConstraints.$size.sink { [weak self] size in
            self?.handleBannerConstraints(size: size)
        }
    }

    override func viewWillDisappear() {
        subscription?.cancel()
        super.viewWillDisappear()
    }

    func createBannerConstraints() {
        guard let contentView = view.window?.contentView else { return }
        self.view.translatesAutoresizingMaskIntoConstraints = false
        if let window = self.view.window {
            centerXConstraint = self.view.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
            topConstraint = self.view.topAnchor.constraint(equalTo: contentView.topAnchor)
            bottomConstraint = self.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)

            heightConstraint = self.view.heightAnchor.constraint(equalToConstant: self.bannerConstraints.size.height)
            widthConstraint = self.view.widthAnchor.constraint(equalToConstant: self.bannerConstraints.size.width)
        }
    }
#else
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        createBannerConstraints()
        handleBannerConstraints(size: self.bannerConstraints.size)
        self.view.layoutIfNeeded()

        if UIAccessibility.isVoiceOverRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + InAppMessageBannerView.animationInOutDuration) {
                self.view.accessibilityViewIsModal = true
                UIAccessibility.post(notification: .screenChanged, argument: self.view)
            }
        }

        subscription = bannerConstraints.$size.sink { [weak self] size in
            self?.handleBannerConstraints(size: size)
            self?.view.layoutIfNeeded()
        }
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

            heightConstraint = self.view.heightAnchor.constraint(equalToConstant: self.bannerConstraints.size.height)
            widthConstraint = self.view.widthAnchor.constraint(equalToConstant: self.bannerConstraints.size.width)
        }
    }
#endif

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
