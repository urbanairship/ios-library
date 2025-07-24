/* Copyright Airship and Contributors */

import SwiftUI

/// AirshipLayout
public struct AirshipLayout: ThomasSerializable {
    /// The view DSL
    let view: ThomasViewInfo

    /// Layout DSL version
    let version: Int

    /// Presentation configuration
    let presentation: ThomasPresentationInfo

    public var isEmbedded: Bool {
        guard case .embedded(_) = presentation else {
            return false
        }

        return true
    }
}


extension AirshipLayout {
    static let minLayoutVersion = 1
    static let maxLayoutVersion = 2

    public func validate() -> Bool
    {
        guard
            self.version >= Self.minLayoutVersion
                && self.version <= Self.maxLayoutVersion else {
            return false
        }

        return true
    }

    func extract<T>(extractor: (ThomasViewInfo) -> T?) -> [T] {
        var infos: [ThomasViewInfo] = [self.view]
        var result: [T] = []
        while (!infos.isEmpty) {
            let info = infos.removeFirst()
            if let children = immediateChildren(info: info) {
                infos.append(contentsOf: children)
            }

            if let value = extractor(info) {
                result.append(value)
            }
        }

        return result
    }


    private func immediateChildren(info: ThomasViewInfo) -> [ThomasViewInfo]? {
        return switch info {
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
        }
    }
}

