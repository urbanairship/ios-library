/* Copyright Airship and Contributors */

import Foundation

extension ThomasViewInfo {
    /// The payload `identifier` for views that define one, mirrored so rendered views can be
    /// targeted by stable id in UI tests.
    var accessibilityIdentifier: String? {
        switch self {
        case .container:
            return nil
        case .linearLayout:
            return nil
        #if !os(tvOS) && !os(watchOS)
        case .webView:
            return nil
        #endif
        case .customView:
            return nil
        case .scrollLayout:
            return nil
        case .media(let info):
            return info.properties.identifier
        case .label:
            return nil
        case .labelButton(let info):
            return info.properties.identifier
        case .imageButton(let info):
            return info.properties.identifier
        case .stackImageButton(let info):
            return info.properties.identifier
        case .stackImageView(let info):
            return info.properties.identifier
        case .emptyView:
            return nil
        case .pager(let info):
            return info.properties.identifier
        case .pagerIndicator:
            return nil
        case .storyIndicator:
            return nil
        case .pagerController(let info):
            return info.properties.identifier
        case .formController(let info):
            return info.properties.identifier
        case .checkbox(let info):
            return info.properties.identifier
        case .checkboxController(let info):
            return info.properties.identifier
        case .radioInput(let info):
            return info.properties.identifier
        case .radioInputController(let info):
            return info.properties.identifier
        case .textInput(let info):
            return info.properties.identifier
        case .score(let info):
            return info.properties.identifier
        case .npsController(let info):
            return info.properties.identifier
        case .toggle(let info):
            return info.properties.identifier
        case .stateController(let info):
            return info.properties.identifier
        case .buttonLayout(let info):
            return info.properties.identifier
        case .basicToggleLayout(let info):
            return info.properties.identifier
        case .checkboxToggleLayout(let info):
            return info.properties.identifier
        case .radioInputToggleLayout(let info):
            return info.properties.identifier
        case .iconView:
            return nil
        case .scoreController(let info):
            return info.properties.identifier
        case .scoreToggleLayout(let info):
            return info.properties.identifier
        case .asyncViewController(let info):
            return info.properties.identifier
        case .videoController(let info):
            return info.properties.identifier
        }
    }
}
