/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
class ThomasViewController<Content> : UIHostingController<Content> where Content : View {
    
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
}
    
