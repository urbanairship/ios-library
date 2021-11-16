/* Copyright Airship and Contributors */

import Foundation

@available(iOS 13.0.0, tvOS 13.0, *)
class ThomasContext : ObservableObject {
    let delegate: ThomasDelegate
    let actionRunner: ActionRunnerProtocol = ThomasActionRunner()

    init(delegate: ThomasDelegate) {
        self.delegate = delegate
    }
}
