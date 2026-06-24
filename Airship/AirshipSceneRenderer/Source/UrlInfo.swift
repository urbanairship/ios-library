/* Copyright Airship and Contributors */

import Foundation

/// Url Info
/// - Note: For internal use only. :nodoc:
public enum URLInfo: Sendable, Equatable {
    case web(url: String, requireNetwork: Bool = true)
    case video(url: String, requireNetwork: Bool = true)
    case image(url: String, prefetch: Bool = true)
}

extension ThomasViewInfo {
    public var urlInfos: [URLInfo] {
        let urls: [[URLInfo]?] = extractDescendants { info in
            switch info {
            case .media(let info):
                switch info.properties.mediaType {
                case .image:
                    var images: [URLInfo] = [.image(url: info.properties.url)]
                    images.append(contentsOf: info.properties.urlSelectors.imageURLInfos)
                    for override in info.overrides?.url ?? [] {
                        if let url = override.value { images.append(.image(url: url)) }
                    }
                    for override in info.overrides?.urlSelectors ?? [] {
                        images.append(contentsOf: override.value.imageURLInfos)
                    }
                    return images
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
                var images: [URLInfo] = []
                switch info.properties.image {
                case .url(let imageModel):
                    images.append(.image(url: imageModel.url))
                    images.append(contentsOf: imageModel.urlSelectors.imageURLInfos)
                case .icon:
                    break
                }
                for override in info.overrides?.image ?? [] {
                    guard case .url(let imageModel) = override.value else { continue }
                    images.append(.image(url: imageModel.url))
                    images.append(contentsOf: imageModel.urlSelectors.imageURLInfos)
                }
                return images.isEmpty ? nil : images
            case .stackImageButton(let info):
                var images: [URLInfo] = []
                for item in info.properties.items {
                    switch item {
                    case .imageURL(let info):
                        images.append(.image(url: info.url))
                        images.append(contentsOf: info.urlSelectors.imageURLInfos)
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
                                images.append(contentsOf: info.urlSelectors.imageURLInfos)
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

private extension Optional where Wrapped == [ThomasMediaUrlSelector] {
    /// Returns `.image` URLInfos for all selectors that can possibly match on iOS.
    /// Platform-specific selectors for other platforms are excluded since they can never match,
    /// but all dark_mode variants are included because the user can switch modes at runtime.
    var imageURLInfos: [URLInfo] {
        guard let selectors = self else { return [] }
        return selectors.compactMap { selector in
            if let platform = selector.platform, platform != .ios { return nil }
            return .image(url: selector.url)
        }
    }
}

extension AirshipLayout {
    public var urlInfos: [URLInfo] {
        view.urlInfos
    }
}


