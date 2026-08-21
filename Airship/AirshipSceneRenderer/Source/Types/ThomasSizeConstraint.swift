/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
@_spi(AirshipInternal) import AirshipBasement

enum ThomasSizeConstraint: ThomasSerializable {
    case points(Double)
    case percent(Double)
    case auto

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let sizeString = try? container.decode(String.self) {
            if sizeString == "auto" {
                self = .auto
            } else if sizeString.last == "%" {
                var perecent = sizeString
                perecent.removeLast()
                self = .percent(Double(perecent) ?? 0)
            } else {
                throw AirshipErrors.parseError("invalid size: \(sizeString)")
            }
        } else if let double = try? container.decode(Double.self) {
            self = .points(double)
        } else {
            throw AirshipErrors.parseError("invalid size")
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .auto:
            try container.encode("auto")
        case .percent(let value):
            try container.encode(String(format: "%.0f%%", value))
        case .points(let value):
            try container.encode(value)
        }
    }
}

extension ThomasSizeConstraint {
    /// Whether an item declared this size, showing [view], gives [axis] a length of its own.
    ///
    /// A percentage is a share of its parent, so it can only be resolved once the parent has a length
    /// to take a share of — it never supplies one. An auto-sized parent takes its length from its
    /// children, so children that all decline to supply one leave it nothing to work from: in
    /// `H(1 - P) = S`, the extent of everything that isn't a percentage is `S = 0`.
    ///
    /// Worth answering on sight rather than solving for. The solver only gets there by feeding a
    /// measurement back through the children that produced it, and at `P >= 1` that loop diverges
    /// instead of settling. Knowing up front that there is no basis lets the percentages fall back to
    /// auto, which is stable and leaves the items visible — `S = 0` also admits `H = 0`, but rendering
    /// an author's `100%` label as an empty box hides the mistake instead of showing it.
    func establishesLength(view: ThomasViewInfo, on axis: Axis) -> Bool {
        switch self {
        case .points: true
        case .percent: false
        // Auto defers to the content, so the question passes down: a stack of percentages is no more
        // able to supply a length than a percentage is, however many wrappers sit in between.
        case .auto: view.establishesLength(on: axis)
        }
    }
}

extension ThomasViewInfo {
    /// Whether anything in this subtree gives [axis] a length that isn't a share of something above it.
    ///
    /// Answers `true` for anything unrecognised. Calling a view basis-less takes the solve away from
    /// the parent and sizes the percentages to their own content instead; declining to leaves the
    /// size solved as it was before. The second is the smaller claim to make about a view we don't
    /// recognise, so uncertainty belongs on the side of leaving the solve alone.
    func establishesLength(on axis: Axis) -> Bool {
        switch self {
        case .container(let info):
            return info.properties.items.contains {
                $0.size.constraint(on: axis).establishesLength(view: $0.view, on: axis)
            }
        case .linearLayout(let info):
            return info.properties.items.contains {
                $0.size.constraint(on: axis).establishesLength(view: $0.view, on: axis)
            }
        default:
            // Everything else either draws content of its own — a label, an image, a text field — or
            // wraps views without resizing them, so what it wraps answers for it.
            guard let children = self.immediateChildren else { return true }
            return children.contains { $0.establishesLength(on: axis) }
        }
    }
}

extension ThomasSize {
    func constraint(on axis: Axis) -> ThomasSizeConstraint {
        axis == .vertical ? self.height : self.width
    }
}
