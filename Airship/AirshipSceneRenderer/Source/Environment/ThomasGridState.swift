/* Copyright Airship and Contributors */

import Foundation
import CoreGraphics
import Combine
@_spi(AirshipInternal) import AirshipBasement

/// A grid's own width, published as `$grids.current.width` to the grid itself, its items and every
/// view inside it, until a nested grid takes over.
///
/// The width comes from the room the grid's parent offers, never its cells, so nothing inside can feed back into it.
/// It isn't persisted: it's re-derived from the offer whenever the grid is built.
@MainActor
final class ThomasGridState: ObservableObject {
    static let stateKey: String = "$grids"

    /// The grid's inner width, or `nil` for a grid with none to measure.
    @Published var width: CGFloat?

    init(width: CGFloat?) {
        self.width = width
    }

    /// Returns the `$grids` state object for a width.
    ///
    /// A `nil` width leaves `width` out, so a predicate on it doesn't match.
    ///
    /// - Parameter width: the grid's inner width, or `nil`
    /// - Returns: the value of `$grids`
    static func json(width: CGFloat?) -> AirshipJSON {
        let current: [String: AirshipJSON] = width.map { ["width": .number(Double($0))] } ?? [:]
        return ["current": .object(current)]
    }
}
