/* Copyright Airship and Contributors */

import Foundation

@MainActor
class RadioInputState: ObservableObject {
    @Published
    var selectedItem: String?
    var attributeValue: AttributeValue?

    func updateSelectedItem(_ model: RadioInputModel?) {
        self.attributeValue = model?.attributeValue
        self.selectedItem = model?.value
    }
}
