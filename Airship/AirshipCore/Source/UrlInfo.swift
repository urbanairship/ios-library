/* Copyright Airship and Contributors */

import Foundation

/// Url Info
/// - Note: for internal use only.  :nodoc:
public enum URLInfo: Sendable, Equatable {
    case web(url: String, requireNetwork: Bool = true)
    case video(url: String, requireNetwork: Bool = true)
    case image(url: String, prefetch: Bool = true)
}

extension AirshipLayout {

    public var urlInfos: [URLInfo] {
        return extract { info in
            switch info {
            case .media(let info):
                switch info.properties.mediaType {
                case .image:
                    return [.image(url: info.properties.url)]
                case .youtube:
                    return [.video(url: info.properties.url)]
                case .vimeo:
                    return [.video(url: info.properties.url)]
                case .video:
                    return [.video(url: info.properties.url)]
                }
            #if !os(tvOS) && !os(watchOS)
            case .webView(let info):
                return [.web(url: info.properties.url)]
            #endif
            case .imageButton(let info):
                switch info.properties.image {
                case .url(let imageModel):
                    return [.image(url: imageModel.url)]
                case .icon(_):
                    return nil
                }
            default: return nil
            }
        }
    }
    
    private func extract<T>(extractor: (ThomasViewInfo) -> [T]?) -> [T] {
        var infos: [ThomasViewInfo] = [self.view]
        var result: [T] = []
        while (!infos.isEmpty) {
            let info = infos.removeFirst()
            if let children = immediateChildren(info: info) {
                infos.append(contentsOf: children)
            }

            if let value = extractor(info) {
                result.append(contentsOf: value)
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
        case .labelButton: nil
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


