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
        return extractUrlInfos(model: self.view) ?? []
    }

    private func extractUrlInfos(model: ThomasViewInfo) -> [URLInfo]? {
        switch model {
        case .container(let info):
            return info.properties.items
                .compactMap { extractUrlInfos(model: $0.view) }
                .reduce([], +)
        case .linearLayout(let model):
            return model.properties.items
                .compactMap { extractUrlInfos(model: $0.view) }
                .reduce([], +)
        case .pager(let model):
            return model.properties.items
                .compactMap { extractUrlInfos(model: $0.view) }
                .reduce([], +)
        case .scrollLayout(let model):
            return extractUrlInfos(model: model.properties.view)
        case .checkboxController(let model):
            return extractUrlInfos(model: model.properties.view)
        case .radioInputController(let model):
            return extractUrlInfos(model: model.properties.view)
        case .formController(let model):
            return extractUrlInfos(model: model.properties.view)
        case .npsController(let model):
            return extractUrlInfos(model: model.properties.view)
        case .pagerController(let model):
            return extractUrlInfos(model: model.properties.view)
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
        case .imageButton(let model):
            switch model.properties.image {
            case .url(let imageModel):
                return [.image(url: imageModel.url)]
            case .icon(_):
                return nil
            }
        case .label(_):
            return nil
        case .labelButton(_):
            return nil
        case .emptyView(_):
            return nil
        case .pagerIndicator(_):
            return nil
        case .storyIndicator(_):
            return nil
        case .checkbox(_):
            return nil
        case .radioInput(_):
            return nil
        case .textInput(_):
            return nil
        case .score(_):
            return nil
        case .toggle(_):
            return nil
        case .stateController(_):
            return nil
        case .customView(_):
            return nil
        case .buttonLayout(let model):
            return extractUrlInfos(model: model.properties.view)
        }
    }
}
