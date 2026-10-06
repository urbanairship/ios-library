/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// A layer painted behind a view's own content.
///
/// A layer never affects the view's own resolved size: the view sizes itself
/// first, using its normal rules, and only afterward are its background
/// layers laid into the resulting box.
enum ThomasBackground: Codable, Equatable, Sendable {
    case color(ColorBackground)
    case gradient(GradientBackground)
    case media(MediaBackground)

    enum BackgroundType: String, Codable, Equatable, Sendable {
        case color
        case gradient
        case media
    }

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(BackgroundType.self, forKey: .type)

        self = switch type {
        case .color: .color(try ColorBackground(from: decoder))
        case .gradient: .gradient(try GradientBackground(from: decoder))
        case .media: .media(try MediaBackground(from: decoder))
        }
    }

    func encode(to encoder: any Encoder) throws {
        switch self {
        case .color(let info): try info.encode(to: encoder)
        case .gradient(let info): try info.encode(to: encoder)
        case .media(let info): try info.encode(to: encoder)
        }
    }

    var blendMode: ThomasBlendMode? {
        switch self {
        case .color(let info): info.blendMode
        case .gradient(let info): info.blendMode
        case .media(let info): info.blendMode
        }
    }

    var opacity: Double? {
        switch self {
        case .color(let info): info.opacity
        case .gradient(let info): info.opacity
        case .media(let info): info.opacity
        }
    }

    /// Whether the layer takes touches: only a video showing its own playback controls does.
    var acceptsTouches: Bool {
        guard case .media(.video(let info)) = self else { return false }
        return info.playerInfo.properties.video?.showControls == true
    }

    struct ColorBackground: ThomasSerializable {
        let type: BackgroundType = .color
        var color: ThomasColor
        var blendMode: ThomasBlendMode?
        var opacity: Double?

        enum CodingKeys: String, CodingKey {
            case type
            case color
            case blendMode = "blend_mode"
            case opacity
        }
    }

    struct GradientBackground: ThomasSerializable {
        let type: BackgroundType = .gradient
        var gradient: Gradient
        var blendMode: ThomasBlendMode?
        var opacity: Double?

        enum CodingKeys: String, CodingKey {
            case type
            case gradient
            case blendMode = "blend_mode"
            case opacity
        }

        struct Gradient: ThomasSerializable {
            var style: Style
            /// Degrees, `linear` only.
            var angle: Double?
            var stops: [Stop]

            enum Style: String, ThomasSerializable {
                case linear
                case radial
            }

            struct Stop: ThomasSerializable {
                var color: ThomasColor
                /// 0 - 1, along the gradient.
                var position: Double
            }

            /// The `LinearGradient` start/end points for a box of `size`, using CSS's
            /// corner-to-corner gradient line length so the box's farthest corner along the
            /// gradient axis lands exactly at the final stop.
            ///
            /// `UnitPoint` alone can't express this: it's a *fraction* of width/height, and the
            /// correct fraction depends on the box's aspect ratio at every angle except the four
            /// axis-aligned ones, where a plain unit vector happens to already be correct.
            static func linearGradientPoints(angle: Double?, size: CGSize) -> (start: UnitPoint, end: UnitPoint) {
                // CSS's angle convention: 0° runs bottom to top, and increases clockwise, so the
                // default (no angle) matches CSS's own default of "to bottom".
                let radians = (angle ?? 180) * .pi / 180
                let dx = sin(radians)
                let dy = -cos(radians)
                let width = size.width
                let height = size.height

                // At axis-aligned angles this reduces to plain width or height.
                let pixelHalfLength = 0.5 * (width * abs(dx) + height * abs(dy))
                let unitDx = width > 0 ? (dx * pixelHalfLength) / width : 0
                let unitDy = height > 0 ? (dy * pixelHalfLength) / height : 0

                return (
                    start: UnitPoint(x: 0.5 - unitDx, y: 0.5 - unitDy),
                    end: UnitPoint(x: 0.5 + unitDx, y: 0.5 + unitDy)
                )
            }
        }
    }

    /// A `media` layer: an image, or a video/youtube/vimeo layer, which alone carries `video`.
    enum MediaBackground: ThomasSerializable {
        case image(ImageMediaBackground)
        case video(VideoMediaBackground)

        struct ImageMediaBackground: ThomasSerializable {
            let type: BackgroundType = .media
            let mediaType: ThomasViewInfo.Media.MediaType = .image
            var url: String
            var urlSelectors: [ThomasMediaUrlSelector]?
            var mediaFit: ThomasMediaFit
            var position: ThomasPosition?
            var blendMode: ThomasBlendMode?
            var opacity: Double?
            var overrides: ThomasViewInfo.Media.Overrides?

            enum CodingKeys: String, CodingKey {
                case type
                case url
                case urlSelectors = "url_selectors"
                case mediaType = "media_type"
                case mediaFit = "media_fit"
                case position
                case blendMode = "blend_mode"
                case opacity
                case overrides = "view_overrides"
            }
        }

        struct VideoMediaBackground: ThomasSerializable {
            let type: BackgroundType = .media
            var url: String
            var urlSelectors: [ThomasMediaUrlSelector]?
            var mediaType: ThomasViewInfo.Media.MediaType
            var mediaFit: ThomasMediaFit
            var position: ThomasPosition?
            var video: ThomasViewInfo.Media.Video?
            var blendMode: ThomasBlendMode?
            var opacity: Double?
            /// The in-flow `media` view this layer plays through, decoded from the same JSON.
            let playerInfo: ThomasViewInfo.Media

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.url = try container.decode(String.self, forKey: .url)
                self.urlSelectors = try container.decodeIfPresent([ThomasMediaUrlSelector].self, forKey: .urlSelectors)
                self.mediaType = try container.decode(ThomasViewInfo.Media.MediaType.self, forKey: .mediaType)
                self.mediaFit = try container.decode(ThomasMediaFit.self, forKey: .mediaFit)
                self.position = try container.decodeIfPresent(ThomasPosition.self, forKey: .position)
                self.video = try container.decodeIfPresent(ThomasViewInfo.Media.Video.self, forKey: .video)
                self.blendMode = try container.decodeIfPresent(ThomasBlendMode.self, forKey: .blendMode)
                self.opacity = try container.decodeIfPresent(Double.self, forKey: .opacity)

                self.playerInfo = try ThomasViewInfo.Media(from: decoder)
            }

            enum CodingKeys: String, CodingKey {
                case type
                case url
                case urlSelectors = "url_selectors"
                case mediaType = "media_type"
                case mediaFit = "media_fit"
                case position
                case video
                case blendMode = "blend_mode"
                case opacity
            }
        }

        private enum CodingKeys: String, CodingKey {
            case mediaType = "media_type"
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let mediaType = try container.decode(ThomasViewInfo.Media.MediaType.self, forKey: .mediaType)
            self = switch mediaType {
            case .image: .image(try ImageMediaBackground(from: decoder))
            case .video, .youtube, .vimeo: .video(try VideoMediaBackground(from: decoder))
            }
        }

        func encode(to encoder: any Encoder) throws {
            switch self {
            case .image(let info): try info.encode(to: encoder)
            case .video(let info): try info.encode(to: encoder)
            }
        }

        // The fields every layer has regardless of `mediaType`, so a caller
        // that doesn't care about `video` never has to switch for them.
        var url: String {
            switch self {
            case .image(let info): info.url
            case .video(let info): info.url
            }
        }

        var urlSelectors: [ThomasMediaUrlSelector]? {
            switch self {
            case .image(let info): info.urlSelectors
            case .video(let info): info.urlSelectors
            }
        }

        var overrides: ThomasViewInfo.Media.Overrides? {
            switch self {
            case .image(let info): info.overrides
            case .video(let info): info.playerInfo.overrides
            }
        }

        var mediaType: ThomasViewInfo.Media.MediaType {
            switch self {
            case .image(let info): info.mediaType
            case .video(let info): info.mediaType
            }
        }

        var mediaFit: ThomasMediaFit {
            switch self {
            case .image(let info): info.mediaFit
            case .video(let info): info.mediaFit
            }
        }

        var position: ThomasPosition? {
            switch self {
            case .image(let info): info.position
            case .video(let info): info.position
            }
        }

        var blendMode: ThomasBlendMode? {
            switch self {
            case .image(let info): info.blendMode
            case .video(let info): info.blendMode
            }
        }

        var opacity: Double? {
            switch self {
            case .image(let info): info.opacity
            case .video(let info): info.opacity
            }
        }

        var video: ThomasViewInfo.Media.Video? {
            switch self {
            case .image: nil
            case .video(let info): info.video
            }
        }
    }
}

/// How far a background layer moves relative to the scroll or drag position
/// of the `Pager`/`ScrollLayout` that holds it, along that host's own direction.
///
/// `factor: 0` pins the layer in place; `1` moves it in lockstep with the
/// content (no visible parallax); a negative factor moves it the other way.
struct ThomasParallax: ThomasSerializable {
    var factor: Double
}

extension Array where Element == ThomasParallaxBackgroundLayer {
    /// Whether any layer moves with its host's content.
    var hasParallax: Bool {
        contains { $0.parallaxFactor != 0 }
    }
}

/// A background layer that may additionally declare `parallax` -- only
/// `ThomasViewInfo.Pager` and `ThomasViewInfo.ScrollLayout` carry these,
/// since they're the only two views with a scroll or drag position for it to
/// read. The other views that carry backgrounds use `ThomasBackground`
/// directly, which has no `parallax` case at all.
struct ThomasParallaxBackgroundLayer: Codable, Equatable, Sendable {
    var background: ThomasBackground
    var parallax: ThomasParallax?

    /// The layer's `parallax.factor`, or 0 when it doesn't move.
    var parallaxFactor: Double {
        parallax?.factor ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case parallax
    }

    init(from decoder: any Decoder) throws {
        self.background = try ThomasBackground(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.parallax = try container.decodeIfPresent(ThomasParallax.self, forKey: .parallax)
    }

    func encode(to encoder: any Encoder) throws {
        try background.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(parallax, forKey: .parallax)
    }
}
