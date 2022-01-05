/* Copyright Airship and Contributors */

import Foundation

@available(iOS 13.0.0, tvOS 13.0, *)
class PagerState: ObservableObject {
    @Published var pageIndex: Int = 0
    @Published var completed: Bool = false
    @Published var pages: [String] = []
    
    let identifier: String

    init(identifier: String) {
        self.identifier = identifier
    }
}
