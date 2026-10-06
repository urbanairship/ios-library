/* Copyright Airship and Contributors */

import Foundation

/// Url Info
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
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
                var images: [URLInfo] = info.properties.items.imageURLInfos

                if let overrides = info.overrides?.items {
                    for override in overrides {
                        guard let item = override.value else { continue }
                        images.append(contentsOf: item.imageURLInfos)
                    }
                }

                return images.isEmpty ? nil : images

            case .stackImageView(let info):
                let images = info.properties.items.imageURLInfos
                return images.isEmpty ? nil : images

            default: return nil
            }
        }

        let backgroundURLs = extractDescendants { $0.backgroundLayers }.joined().flatMap(\.urlInfos)

        return urls.compactMap { $0 }.reduce(into: []) { result, urlArray in
            result.append(contentsOf: urlArray)
        } + backgroundURLs
    }

    /// The `backgrounds` layers this view paints behind itself, or `nil` for a view that has none.
    private var backgroundLayers: [ThomasBackground]? {
        switch self {
        case .container(let info): info.properties.backgrounds
        case .linearLayout(let info): info.properties.backgrounds
        case .gridLayout(let info): info.properties.backgrounds
        case .scrollLayout(let info): info.properties.backgrounds?.map(\.background)
        case .pager(let info): info.properties.backgrounds?.map(\.background)
        case .buttonLayout(let info): info.properties.backgrounds
        case .basicToggleLayout(let info): info.properties.backgrounds
        case .checkboxToggleLayout(let info): info.properties.backgrounds
        case .radioInputToggleLayout(let info): info.properties.backgrounds
        case .scoreToggleLayout(let info): info.properties.backgrounds
        default: nil
        }
    }
}

private extension ThomasBackground {
    /// The URLs a `media` layer loads; color and gradient layers load none.
    var urlInfos: [URLInfo] {
        guard case .media(let media) = self else { return [] }
        switch media.mediaType {
        case .image:
            var images: [URLInfo] = [.image(url: media.url)] + media.urlSelectors.imageURLInfos
            for override in media.overrides?.url ?? [] {
                if let url = override.value { images.append(.image(url: url)) }
            }
            for override in media.overrides?.urlSelectors ?? [] {
                images.append(contentsOf: override.value.imageURLInfos)
            }
            return images
        case .video, .youtube, .vimeo:
            return [.video(url: media.url)]
        }
    }
}

private extension Sequence where Element == ThomasViewInfo.StackImageButton.Item {
    /// `.image` URLInfos for all image items in a stack image button/view.
    var imageURLInfos: [URLInfo] {
        var images: [URLInfo] = []
        for item in self {
            switch item {
            case .imageURL(let info):
                images.append(.image(url: info.url))
                images.append(contentsOf: info.urlSelectors.imageURLInfos)
            case .icon, .shape:
                break
            }
        }
        return images
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


