/* Copyright Airship and Contributors */

import Foundation

@MainActor
class RadioInputState: ObservableObject {

    @Published
    var selectedItem: AirshipJSON?

    var attributeValue: ThomasAttributeValue?

    func updateSelectedItem(
        reportingValue: AirshipJSON,
        attributeValue: ThomasAttributeValue?
    ) {
        self.selectedItem = reportingValue
        self.attributeValue = attributeValue
    }
}
