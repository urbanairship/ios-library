/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Media info
public struct InAppMessageMediaInfo: Sendable, Codable, Equatable {

    /// Media type
    public enum MediaType: String, Sendable, Codable {

        /// Youtube videos
        case youtube
        /// Vimeo videos
        case vimeo
        /// HTML video
        case video
        /// Image
        case image
    }

    /// The media's URL
    public var url: String

    /// The media's type
    public var type: MediaType

    /// Content description
    public var description: String?


    /// In-app message media model
    /// - Parameters:
    ///   - url: URL from which to fetch the media
    ///   - type: Media type
    ///   - description: Content description for accessibility purposes
    public init(
        url: String,
        type: MediaType,
        description: String? = nil
    ) {
        self.url = url
        self.type = type
        self.description = description
    }

    enum CodingKeys: String, CodingKey {
        case url
        case type
        case description
    }
}
