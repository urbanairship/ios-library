/* Copyright Airship and Contributors */


import SwiftUI

class ChannelListViewHostingController<Content>: UIHostingController<Content> where Content: View {
    init(
        rootView: Content,
        backgroundColor: UIColor? = nil
    ) {
        super.init(rootView: rootView)
        if let backgroundColor = backgroundColor {
            self.view.backgroundColor = backgroundColor
        }
    }

    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
