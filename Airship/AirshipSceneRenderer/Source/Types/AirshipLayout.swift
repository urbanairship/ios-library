/* Copyright Airship and Contributors */

import SwiftUI

/// AirshipLayout
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct AirshipLayout: ThomasSerializable {
    /// The view DSL
    let view: ThomasViewInfo

    /// Layout DSL version
    let version: Int

    /// Presentation configuration
    public let presentation: ThomasPresentationInfo

    /// Layout control options
    /// - Note: For internal use only. :nodoc:
    public let options: NativeLayoutControlOptions?

    public var isEmbedded: Bool {
        guard case .embedded(_) = presentation else {
            return false
        }

        return true
    }
}

extension ThomasViewInfo {
    func extractDescendants<T>(extractor: (ThomasViewInfo) -> T?) -> [T] {
        var infos: [ThomasViewInfo] = [self]
        var result: [T] = []
        while (!infos.isEmpty) {
            let info = infos.removeFirst()
            if let children = info.immediateChildren {
                infos.append(contentsOf: children)
            }

            if let value = extractor(info) {
                result.append(value)
            }
        }

        return result
    }

    /// The stroke this view draws around itself, which sits inside a length it was given.
    ///
    /// A parent needs it while it is still deciding the child's frame: the length in the payload is
    /// the whole footprint, and the border is part of what fits inside it.
    ///
    /// The widest stroke the view could draw, not the one it draws right now. A border can be
    /// overridden per state, and the frame is settled here — before any state exists — while the
    /// padding is applied later by a modifier that resolves the override. Reserving the widest keeps
    /// the view inside its declared footprint whichever state it lands in; a narrower one leaves it
    /// slightly under, which is the harmless direction.
    var borderStrokeWidth: Double {
        let strokes = [borderProperties.0?.strokeWidth]
            + (borderProperties.1?.map { $0.value?.strokeWidth } ?? [])
        return strokes.compactMap { $0 }.max() ?? 0
    }

    private var borderProperties: (ThomasBorder?, [ThomasPropertyOverride<ThomasBorder>]?) {
        let properties: (CommonViewProperties, CommonViewOverrides?) = switch self {
        case .container(let info): (info.commonProperties, info.commonOverrides)
        case .linearLayout(let info): (info.commonProperties, info.commonOverrides)
        #if !os(tvOS) && !os(watchOS)
        case .webView(let info): (info.commonProperties, info.commonOverrides)
        #endif
        case .customView(let info): (info.commonProperties, info.commonOverrides)
        case .scrollLayout(let info): (info.commonProperties, info.commonOverrides)
        case .media(let info): (info.commonProperties, info.commonOverrides)
        case .label(let info): (info.commonProperties, info.commonOverrides)
        case .labelButton(let info): (info.commonProperties, info.commonOverrides)
        case .imageButton(let info): (info.commonProperties, info.commonOverrides)
        case .stackImageButton(let info): (info.commonProperties, info.commonOverrides)
        case .stackImageView(let info): (info.commonProperties, info.commonOverrides)
        case .emptyView(let info): (info.commonProperties, info.commonOverrides)
        case .pager(let info): (info.commonProperties, info.commonOverrides)
        case .pagerIndicator(let info): (info.commonProperties, info.commonOverrides)
        case .storyIndicator(let info): (info.commonProperties, info.commonOverrides)
        case .pagerController(let info): (info.commonProperties, info.commonOverrides)
        case .formController(let info): (info.commonProperties, info.commonOverrides)
        case .checkbox(let info): (info.commonProperties, info.commonOverrides)
        case .checkboxController(let info): (info.commonProperties, info.commonOverrides)
        case .radioInput(let info): (info.commonProperties, info.commonOverrides)
        case .radioInputController(let info): (info.commonProperties, info.commonOverrides)
        case .textInput(let info): (info.commonProperties, info.commonOverrides)
        case .score(let info): (info.commonProperties, info.commonOverrides)
        case .npsController(let info): (info.commonProperties, info.commonOverrides)
        case .toggle(let info): (info.commonProperties, info.commonOverrides)
        case .stateController(let info): (info.commonProperties, info.commonOverrides)
        case .buttonLayout(let info): (info.commonProperties, info.commonOverrides)
        case .basicToggleLayout(let info): (info.commonProperties, info.commonOverrides)
        case .checkboxToggleLayout(let info): (info.commonProperties, info.commonOverrides)
        case .radioInputToggleLayout(let info): (info.commonProperties, info.commonOverrides)
        case .iconView(let info): (info.commonProperties, info.commonOverrides)
        case .scoreController(let info): (info.commonProperties, info.commonOverrides)
        case .scoreToggleLayout(let info): (info.commonProperties, info.commonOverrides)
        case .asyncViewController(let info): (info.commonProperties, info.commonOverrides)
        case .videoController(let info): (info.commonProperties, info.commonOverrides)
        }
        return (properties.0.border, properties.1?.border)
    }

    /// Nil for a view that draws its own content rather than hosting other views.
    var immediateChildren: [ThomasViewInfo]? {
        return switch self {
        case .container(let info): info.properties.items.map { $0.view }
        case .linearLayout(let info): info.properties.items.map { $0.view }
        case .pager(let info): info.properties.items.map { $0.view }
        case .scrollLayout(let info): [info.properties.view]
        case .checkboxController(let info): [info.properties.view]
        case .radioInputController(let info): [info.properties.view]
        case .formController(let info): [info.properties.view]
        case .npsController(let info): [info.properties.view]
        case .pagerController(let info): [info.properties.view]
        case .media: nil
        case .imageButton: nil
        case .stackImageButton: nil
        case .stackImageView: nil
        #if !os(tvOS) && !os(watchOS)
        case .webView: nil
        #endif
        case .label: nil
        case .labelButton(let info): [.label(info.properties.label)]
        case .emptyView: nil
        case .pagerIndicator(_): nil
        case .storyIndicator(_): nil
        case .checkbox(_): nil
        case .radioInput(_): nil
        case .textInput(_): nil
        case .score(_): nil
        case .toggle(_): nil
        case .stateController(let info): [info.properties.view]
        case .customView: nil
        case .buttonLayout(let info): [info.properties.view]
        case .basicToggleLayout(let info): [info.properties.view]
        case .checkboxToggleLayout(let info): [info.properties.view]
        case .radioInputToggleLayout(let info): [info.properties.view]
        case .iconView: nil
        case .scoreController(let info): [info.properties.view]
        case .scoreToggleLayout(let info): [info.properties.view]
        case .asyncViewController: nil
        case .videoController(let info): [info.properties.view]
        }
    }
}

extension AirshipLayout {
    static let minLayoutVersion: Int = 1
    static let maxLayoutVersion: Int = 2

    public static func isValidVersion(_ version: Int) -> Bool {
        return version >= minLayoutVersion && version <= maxLayoutVersion
    }

    public func validate() -> Bool {
        return Self.isValidVersion(self.version)
    }

    func extract<T>(extractor: (ThomasViewInfo) -> T?) -> [T] {
        return self.view.extractDescendants(extractor: extractor)
    }
}
