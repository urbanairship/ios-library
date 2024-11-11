/* Copyright Airship and Contributors */

import Foundation

@MainActor
class RadioInputState: ObservableObject {
    @Published
    var selectedItem: String?
    var attributeValue: ThomasAttributeValue?

    func updateSelectedItem(_ info: ThomasViewInfo.RadioInput?) {
        self.attributeValue = info?.properties.attributeValue
        self.selectedItem = info?.properties.reportingValue
    }
}
