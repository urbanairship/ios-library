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
