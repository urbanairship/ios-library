/* Copyright Airship and Contributors */


import SwiftUI

@MainActor
class CheckboxState: ObservableObject {

    let minSelection: Int
    let maxSelection: Int

    @Published
    var selected: Set<Selected> = Set()

    init(minSelection: Int?, maxSelection: Int?) {
        self.minSelection = minSelection ?? 0
        self.maxSelection = maxSelection ?? Int.max
    }

    var isMaxSelectionReached: Bool {
        selected.count >= maxSelection
    }

    func isSelected(identifier: String) -> Bool {
        return selected.contains { item in
            item.identifier == identifier
        }
    }

    func isSelected(reportingValue: AirshipJSON) -> Bool {
        return selected.contains { item in
            item.reportingValue == reportingValue
        }
    }

    struct Selected: Sendable, Equatable, Hashable {
        var identifier: String?
        var reportingValue: AirshipJSON
    }
}

extension CheckboxState {
    func makeBinding(
        identifier: String?,
        reportingValue: AirshipJSON
    ) -> Binding<Bool> {
        return Binding<Bool>(
            get: {
                if let identifier {
                    self.isSelected(
                        identifier: identifier
                    )
                } else {
                    self.isSelected(
                        reportingValue: reportingValue
                    )
                }
            },
            set: {
                let selected = Selected(
                    identifier: identifier,
                    reportingValue: reportingValue
                )
                if $0 {
                    self.selected.insert(selected)
                } else {
                    self.selected.remove(selected)
                }
            }
        )
    }
}
