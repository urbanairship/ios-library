/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
class ThomasViewController<Content> : UIHostingController<Content> where Content : View {
    
    var options: ThomasViewControllerOptions
    var onDismiss: (() -> Void)?
    
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
}

class ThomasViewControllerOptions {
    var orientation: Orientation?
}


    
