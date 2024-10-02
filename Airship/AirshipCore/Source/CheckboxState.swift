/* Copyright Airship and Contributors */

import Foundation

@MainActor
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
