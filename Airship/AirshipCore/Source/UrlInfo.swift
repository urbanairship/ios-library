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
                    return .image(url: info.properties.url)
                case .youtube:
                    return .video(url: info.properties.url)
                case .vimeo:
                    return .video(url: info.properties.url)
                case .video:
                    return .video(url: info.properties.url)
                }
            #if !os(tvOS) && !os(watchOS)
            case .webView(let info):
                return .web(url: info.properties.url)
            #endif
            case .imageButton(let info):
                switch info.properties.image {
                case .url(let imageModel):
                    return .image(url: imageModel.url)
                case .icon(_):
                    return nil
                }
            default: return nil
            }
        }
    }
}


