/* Copyright Airship and Contributors */

import Foundation
import CoreGraphics
import Combine
@_spi(AirshipInternal) import AirshipBasement

/// A grid's `grid_state.conditions`, chosen from its width and published as `$grids.current.conditions`
/// to the grid itself, its items and every view inside it, until a nested grid takes over.
///
/// The width comes from the room the grid's parent offers, never its cells, so nothing inside can feed back into it.
/// It isn't persisted: it's re-derived from the offer whenever the grid is built.
@MainActor
final class ThomasGridState: ObservableObject {
    static let stateKey: String = "$grids"

    private let conditions: [String: [ThomasGridConditionSelector]]?

    /// The grid's inner width, or `nil` for a grid with none to measure.
    var width: CGFloat? {
        didSet {
            let chosen = ThomasConditions.chooseGrid(conditions, width: width)
            if chosen != self.chosen { self.chosen = chosen }
        }
    }

    /// Each condition's chosen value, which changes only when the width crosses a breakpoint.
    @Published private(set) var chosen: [String: AirshipJSON]

    init(width: CGFloat?, conditions: [String: [ThomasGridConditionSelector]]? = nil) {
        self.conditions = conditions
        self.width = width
        self.chosen = ThomasConditions.chooseGrid(conditions, width: width)
    }

    /// Returns the `$grids` state object for a grid's chosen conditions.
    ///
    /// - Parameter conditions: each condition's chosen value
    /// - Returns: the value of `$grids`
    static func json(conditions: [String: AirshipJSON]) -> AirshipJSON {
        ["current": ["conditions": .object(conditions)]]
    }
}
