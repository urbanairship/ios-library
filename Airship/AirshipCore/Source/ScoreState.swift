/* Copyright Airship and Contributors */

import Foundation
import Combine

@MainActor
final class ScoreState: ObservableObject {
    
    @Published
    private(set) var selected: Selected?

    let entries: [ThomasViewInfo.ScoreToggleLayout]

    init(info: ThomasViewInfo.ScoreController) {
        self.entries = info.properties.view.extractDescendants { info in
            return if case let .scoreToggleLayout(score) = info {
                score
            } else {
                nil
            }
        }
    }

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

    private var currentIndex: Int? {
        guard let selected else { return nil }
        return entries.firstIndex { layout in
            layout.properties.identifier == selected.identifier
        }
    }

    var accessibilityValue: String? {
        guard
            let currentIndex,
            entries.isEmpty == false
        else {
            return nil
        }

        return entries[currentIndex].accessible.resolveContentDescription
    }

    func incrementScore() {
        guard entries.isEmpty == false else { return }
        guard let currentIndex else {
            updateSelected(entry: entries[0])
            return
        }

        let nextEntry = min(currentIndex + 1, entries.count - 1)
        updateSelected(entry: entries[nextEntry])
    }

    func decrementScore() {
        guard entries.isEmpty == false else { return }
        guard let currentIndex else {
            updateSelected(entry: entries[0])
            return
        }

        let nextEntry = max(currentIndex - 1, 0)
        updateSelected(entry: entries[nextEntry])
    }

    private func updateSelected(entry: ThomasViewInfo.ScoreToggleLayout) {
        self.selected = .init(
            identifier: entry.properties.identifier,
            reportingValue: entry.properties.reportingValue,
            attributeValue: entry.properties.attributeValue
        )
    }

    struct Selected: ThomasSerializable, Hashable {
        var identifier: String
        var reportingValue: AirshipJSON
        var attributeValue: ThomasAttributeValue?
    }
}

//MARK: - State provider
extension ScoreState: ThomasStateProvider {
    typealias SnapshotType = Selected?
    
    var updates: AnyPublisher<any Codable, Never> {
        return $selected
            .removeDuplicates()
            .map(\.self)
            .eraseToAnyPublisher()
    }
    
    func persistentStateSnapshot() -> SnapshotType {
        return selected
    }
    
    func restorePersistentState(_ state: SnapshotType) {
        self.selected = state
    }
}
