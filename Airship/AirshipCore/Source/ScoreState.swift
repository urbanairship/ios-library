/* Copyright Airship and Contributors */

import Foundation
import Combine

@MainActor
final class ScoreState: ObservableObject {

    @Published
    private(set) var selected: Selected?

    func setSelected(
        identifier: String,
        reportingValue: AirshipJSON,
        attributeValue: ThomasAttributeValue?
    ) {
        let incoming = Selected(
            identifier: identifier,
            reportingValue: reportingValue,
            attributeValue: attributeValue
        )
        if (incoming != self.selected) {
            self.selected = incoming
        }
    }

    struct Selected: Sendable, Equatable, Hashable {
        var identifier: String
        var reportingValue: AirshipJSON
        var attributeValue: ThomasAttributeValue?
    }
}
