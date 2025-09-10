/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

@MainActor
class RadioInputState: ObservableObject {

    @Published
    private(set) var selected: Selected?

    func setSelected(
        identifier: String?,
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
        var identifier: String?
        var reportingValue: AirshipJSON
        var attributeValue: ThomasAttributeValue?
    }
}

extension RadioInputState {
    func makeBinding(
        identifier: String?,
        reportingValue: AirshipJSON,
        attributeValue: ThomasAttributeValue?
    ) -> Binding<Bool> {
        return Binding<Bool>(
            get: {
                if let identifier {
                    self.selected?.identifier == identifier
                } else {
                    self.selected?.reportingValue == reportingValue
                }
            },
            set: {
                if $0 {
                    self.setSelected(
                        identifier: identifier,
                        reportingValue: reportingValue,
                        attributeValue: attributeValue
                    )
                }
            }
        )
    }
}
