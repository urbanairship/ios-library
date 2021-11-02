/* Copyright Airship and Contributors */

import Foundation

@available(iOS 13.0.0, tvOS 13.0, *)
class CheckboxState: ObservableObject {
    let minSelection: Int
    let maxSelection: Int
    
    @Published
    var selectedItems: Set<String> = Set()
    
    init(minSelection: Int?, maxSelection: Int?) {
        self.minSelection = minSelection ?? 0
        self.maxSelection = maxSelection ?? Int.max
    }
}






