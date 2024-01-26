/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


/// In-App message display content
public enum InAppMessageDisplayContent: Sendable, Equatable {
    /// Banner messages
    case banner(Banner)

    /// Fullscreen messages
    case fullscreen(Fullscreen)

    /// Modal messages
    case modal(Modal)

    /// Html messages
    case html(HTML)

    /// Custom messages
    case custom(AirshipJSON)

    /// Airship layout messages
    case airshipLayout(AirshipLayout)


    /// Banner display content
    public struct Banner: Codable, Sendable, Equatable {

        /// Banner layout templates
        public enum Template: String, Codable, Sendable {
            /// Media left
            case mediaLeft = "media_left"
            /// Media right
            case mediaRight = "media_right"
        }

        /// Bannner placement
        public enum Placement: String, Codable, Sendable, Equatable {
            /// Top
            case top
            /// Bottom
            case bottom
        }

        /// The heading
        public var heading: InAppMessageTextInfo?

        /// The body
        public var body: InAppMessageTextInfo?

        /// The media
        public var media: InAppMessageMediaInfo?

        /// The buttons
        public var buttons: [InAppMessageButtonInfo]?

        /// The button layout type
        public var buttonLayoutType: InAppMessageButtonLayoutType?

        /// The template
        public var template: Template?

        /// The  background color
        public var backgroundColor: InAppMessageColor?

        /// The dismiss button color
        public var dismissButtonColor: InAppMessageColor?

        /// The border radius
        public var borderRadius: Double?

        /// How long the banner displays
        public var duration: TimeInterval?

        /// Banner placement
        public var placement: Placement?

        /// Tap actions
        public var actions: AirshipJSON?

        enum CodingKeys: String, CodingKey {
            case actions
            case heading
            case body
            case media
            case buttons
            case buttonLayoutType = "button_layout"
            case template
            case backgroundColor = "background_color"
            case dismissButtonColor = "dismiss_button_color"
            case borderRadius = "border_radius"
            case duration
            case placement
        }

        public init(
            heading: InAppMessageTextInfo? = nil,
            body: InAppMessageTextInfo? = nil,
            media: InAppMessageMediaInfo? = nil,
            buttons: [InAppMessageButtonInfo]? = nil,
            buttonLayoutType: InAppMessageButtonLayoutType? = nil,
            template: Template? = nil,
            backgroundColor: InAppMessageColor? = nil, 
            dismissButtonColor: InAppMessageColor? = nil,
            borderRadius: Double? = nil,
            duration: TimeInterval? = nil,
            placement: Placement? = nil,
            actions: AirshipJSON? = nil
        ) {
            self.heading = heading
            self.body = body
            self.media = media
            self.buttons = buttons
            self.buttonLayoutType = buttonLayoutType
            self.template = template
            self.backgroundColor = backgroundColor
            self.dismissButtonColor = dismissButtonColor
            self.borderRadius = borderRadius
            self.duration = duration
            self.placement = placement
            self.actions = actions
        }
    }

    /// Modal display content
    public struct Modal: Codable, Sendable, Equatable {

        /// Modal templates
        public enum Template: String, Codable, Sendable {
            /// Header, media, body
            case headerMediaBody = "header_media_body"
            /// Media, header, body
            case mediaHeaderBody = "media_header_body"
            /// Header, body, media
            case headerBodyMedia = "header_body_media"
        }

        /// The heading
        public var heading: InAppMessageTextInfo?

        /// The body
        public var body: InAppMessageTextInfo?

        /// The media
        public var media: InAppMessageMediaInfo?

        /// The footer
        public var footer: InAppMessageMediaInfo?

        /// The buttons
        public var buttons: [InAppMessageButtonInfo]?

        /// The button layout type
        public var buttonLayoutType: InAppMessageButtonLayoutType?

        /// The template
        public var template: Template?

        /// The background color
        public var backgroundColor: InAppMessageColor?

        /// The dismiss button color
        public var dismissButtonColor: InAppMessageColor?

        /// The border radius
        public var borderRadius: Double?

        /// If the modal can be displayed as fullscreen on small devices
        public var allowFullscreenDisplay: Bool?

        enum CodingKeys: String, CodingKey {
            case heading
            case body
            case media
            case footer
            case buttons
            case buttonLayoutType = "button_layout"
            case template
            case backgroundColor = "background_color"
            case dismissButtonColor = "dismiss_button_color"
            case borderRadius = "border_radius"
            case allowFullscreenDisplay = "allow_fullscreen_display"
        }

        public init(
            heading: InAppMessageTextInfo? = nil,
            body: InAppMessageTextInfo? = nil,
            media: InAppMessageMediaInfo? = nil,
            footer: InAppMessageMediaInfo? = nil,
            buttons: [InAppMessageButtonInfo],
            buttonLayoutType: InAppMessageButtonLayoutType? = nil,
            template: Template,
            dismissButtonColor: InAppMessageColor? = nil,
            backgroundColor: InAppMessageColor? = nil,
            borderRadius: Double? = nil,
            allowFullscreenDisplay: Bool? = nil
        ) {
            self.heading = heading
            self.body = body
            self.media = media
            self.footer = footer
            self.buttons = buttons
            self.buttonLayoutType = buttonLayoutType
            self.template = template
            self.backgroundColor = backgroundColor
            self.dismissButtonColor = dismissButtonColor
            self.borderRadius = borderRadius
            self.allowFullscreenDisplay = allowFullscreenDisplay
        }
    }

    /// Fullscreen display content
    public struct Fullscreen: Codable, Sendable, Equatable {

        /// Fullscreen templates
        public enum Template: String, Codable, Sendable {
            /// Header, media, body
            case headerMediaBody = "header_media_body"
            /// Media, header, body
            case mediaHeaderBody = "media_header_body"
            /// Header, body, media
            case headerBodyMedia = "header_body_media"
        }

        /// The heading
        public var heading: InAppMessageTextInfo?

        /// The body
        public var body: InAppMessageTextInfo?

        /// The media
        public var media: InAppMessageMediaInfo?

        /// The footer
        public var footer: InAppMessageButtonInfo?

        /// The buttons
        public var buttons: [InAppMessageButtonInfo]?

        /// The button layout type
        public var buttonLayoutType: InAppMessageButtonLayoutType?

        /// The template
        public var template: Template?

        /// The  background color
        public var backgroundColor: InAppMessageColor?

        /// The dismiss button color
        public var dismissButtonColor: InAppMessageColor?

        enum CodingKeys: String, CodingKey {
            case heading
            case body
            case media
            case footer
            case buttons
            case buttonLayoutType = "button_layout"
            case template
            case backgroundColor = "background_color"
            case dismissButtonColor = "dismiss_button_color"
        }

        public init(heading: InAppMessageTextInfo? = nil,
             body: InAppMessageTextInfo? = nil,
             media: InAppMessageMediaInfo? = nil,
             footer: InAppMessageButtonInfo? = nil,
             buttons: [InAppMessageButtonInfo],
             buttonLayoutType: InAppMessageButtonLayoutType? = nil,
             template: Template,
             dismissButtonColor: InAppMessageColor? = nil,
             backgroundColor: InAppMessageColor? = nil
        ) {
            self.heading = heading
            self.body = body
            self.media = media
            self.footer = footer
            self.buttons = buttons
            self.buttonLayoutType = buttonLayoutType
            self.template = template
            self.backgroundColor = backgroundColor
            self.dismissButtonColor = dismissButtonColor
        }
    }

    /// HTML display content
    public struct HTML: Codable, Sendable, Equatable {

        /// The URL
        public var url: String

        /// The height of the manually sized HTML view
        public var height: Double?

        /// The width of the manually sized HTML view
        public var width: Double?

        /// Flag indicating if the HTML view should lock its aspect ratio when resizing to fit the screen
        public var aspectLock: Bool?

        /// Flag indicating if the content requires connectivity to display correctly
        public var requiresConnectivity: Bool?

        /// The dismiss button color
        public var dismissButtonColor: InAppMessageColor?

        /// The  background color
        public var backgroundColor: InAppMessageColor?

        /// The border radius
        public var borderRadius: Double?

        /// If the html can be displayed as fullscreen on small devices
        public var allowFullscreen: Bool?

        enum CodingKeys: String, CodingKey {
            case url
            case height
            case width
            case aspectLock = "aspect_lock"
            case requiresConnectivity = "require_connectivity"
            case backgroundColor = "background_color"
            case dismissButtonColor = "dismiss_button_color"
            case borderRadius = "border_radius"
            case allowFullscreen = "allow_fullscreen_display"
        }

        public init(
            url: String,
            height: Double? = nil,
            width: Double? = nil,
            aspectLock: Bool? = nil,
            requiresConnectivity: Bool? = nil,
            dismissButtonColor: InAppMessageColor? = nil,
            backgroundColor: InAppMessageColor? = nil,
            borderRadius: Double? = nil,
            allowFullscreen: Bool? = nil
        ) {
            self.url = url
            self.height = height
            self.width = width
            self.aspectLock = aspectLock
            self.requiresConnectivity = requiresConnectivity
            self.backgroundColor = backgroundColor
            self.dismissButtonColor = dismissButtonColor
            self.borderRadius = borderRadius
            self.allowFullscreen = allowFullscreen
        }
    }
}

