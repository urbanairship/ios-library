/* Copyright Airship and Contributors */

public import Foundation
public import UIKit
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Embedded view controller factory
@objc
public final class UAEmbeddedViewControllerFactory: NSObject, Sendable {

    @MainActor
    @objc
    public class func makeViewController(embeddedID: String) -> UIViewController {
        let vc = UIHostingController(rootView: AirshipEmbeddedView<EmptyView>(embeddedID: embeddedID))
        // Let Auto Layout drive the height from the SwiftUI content's natural size
        if #available(iOS 16.0, *) {
            vc.sizingOptions = .intrinsicContentSize
        }
        return vc
    }

    @MainActor
    @objc
    public class func embed(embeddedID: String, in parentViewController: UIViewController) -> UIView {
        let childVC = makeViewController(embeddedID: embeddedID)
        parentViewController.addChild(childVC)
        let containerView = UIView(frame: .zero)
        containerView.addSubview(childVC.view)
        childVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            childVC.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            childVC.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            childVC.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            childVC.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        childVC.didMove(toParent: parentViewController)
        return containerView
    }
}
