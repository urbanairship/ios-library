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
        let urls: [[URLInfo]?] = extract { info in
            switch info {
            case .media(let info):
                return switch info.properties.mediaType {
                case .image:
                    [.image(url: info.properties.url)]
                case .youtube:
                    [.video(url: info.properties.url)]
                case .vimeo:
                    [.video(url: info.properties.url)]
                case .video:
                    [.video(url: info.properties.url)]
                }
            #if !os(tvOS) && !os(watchOS)
            case .webView(let info):
                return [.web(url: info.properties.url)]
            #endif
            case .imageButton(let info):
                return switch info.properties.image {
                case .url(let imageModel):
                    [.image(url: imageModel.url)]
                case .icon:
                    nil
                }
            case .stackImageButton(let info):
                var images: [URLInfo] = []
                for item in info.properties.items {
                    switch item {
                    case .imageURL(let info):
                        images.append(.image(url: info.url))
                    case .icon, .shape:
                        break
                    }
                }

                if let overrides = info.overrides?.items {
                    for override in overrides {
                        guard let item = override.value else { continue }
                        for value in item {
                            switch value {
                            case .imageURL(let info):
                                images.append(.image(url: info.url))
                            case .icon, .shape:
                                break
                            }
                        }
                    }
                }

                return images

            default: return nil
            }
        }

        return urls.compactMap { $0 }.reduce(into: []) { result, urlArray in
              result.append(contentsOf: urlArray)
          }
    }
}


