/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

enum InAppMessageSource: String, Codable, Equatable, Sendable {
    case remoteData = "remote-data"
    case appDefined = "app-defined"
    case legacyPush = "legacy-push"
}

/// In-App Message
public struct InAppMessage: Codable, Equatable, Sendable {

    /// Display behavior
    public enum DisplayBehavior: String, Codable, Equatable, Sendable {
        /// Immediate display, allows it to be displayed on top of other IAX
        case immediate

        /// Displays one at a time with display interval between displays
        case standard = "default"
    }

    /// The name.
    public var name: String

    /// Display content
    public var displayContent: InAppMessageDisplayContent

    /// Source
    var source: InAppMessageSource?

    /// Any message extras.
    public var extras: AirshipJSON?

    /// Display actions.
    public var actions: AirshipJSON?

    /// If reporting is enabled or not for the message.
    public var isReportingEnabled: Bool?

    /// Display behavior
    public var displayBehavior: DisplayBehavior?

    /// Rendered locale
    var renderedLocale: AirshipJSON?

    enum CodingKeys: String, CodingKey {
        case name
        case extras = "extra"
        case actions
        case isReportingEnabled = "reporting_enabled"
        case displayBehavior = "display_behavior"
        case display
        case layout
        case displayType = "display_type"
        case renderedLocale = "rendered_locale"
        case source
    }


    /// In-app message constructor
    /// - Parameters:
    ///   - name: Name of the message
    ///   - displayContent: Content model to be displayed in the message
    ///   - extras: Extras payload as JSON
    ///   - actions: Actions to be executed by the message as JSON
    ///   - isReportingEnabled: Reporting enabled flag
    ///   - displayBehavior: Display behavior
    public init(
        name: String,
        displayContent: InAppMessageDisplayContent,
        extras: AirshipJSON? = nil,
        actions: AirshipJSON? = nil,
        isReportingEnabled: Bool? = nil,
        displayBehavior: DisplayBehavior? = nil
    ) {
        self.name = name
        self.displayContent = displayContent
        self.extras = extras
        self.actions = actions
        self.isReportingEnabled = isReportingEnabled
        self.displayBehavior = displayBehavior
        self.renderedLocale = nil
        self.source = .appDefined
    }

    init(
        name: String,
        displayContent: InAppMessageDisplayContent,
        source: InAppMessageSource?,
        extras: AirshipJSON? = nil,
        actions: AirshipJSON? = nil,
        isReportingEnabled: Bool? = nil,
        displayBehavior: DisplayBehavior? = nil,
        renderedLocale: AirshipJSON? = nil
    ) {
        self.name = name
        self.displayContent = displayContent
        self.source = source
        self.extras = extras
        self.actions = actions
        self.isReportingEnabled = isReportingEnabled
        self.displayBehavior = displayBehavior
        self.renderedLocale = renderedLocale

    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        let source = try container.decodeIfPresent(InAppMessageSource.self, forKey: .source)
        let extras = try container.decodeIfPresent(AirshipJSON.self, forKey: .extras)
        let actions = try container.decodeIfPresent(AirshipJSON.self, forKey: .actions)
        let isReportingEnabled = try container.decodeIfPresent(Bool.self, forKey: .isReportingEnabled)
        let displayBehavior = try container.decodeIfPresent(DisplayBehavior.self, forKey: .displayBehavior)
        let renderedLocale = try container.decodeIfPresent(AirshipJSON.self, forKey: .renderedLocale)

        let displayType = try container.decode(DisplayType.self, forKey: .displayType)

        var displayContent: InAppMessageDisplayContent!

        switch (displayType) {
        case .banner:
            let banner = try container.decode(InAppMessageDisplayContent.Banner.self, forKey: .display)
            displayContent = .banner(banner)
        case .modal:
            let modal = try container.decode(InAppMessageDisplayContent.Modal.self, forKey: .display)
            displayContent = .modal(modal)
        case .fullscreen:
            let fullscreen = try container.decode(InAppMessageDisplayContent.Fullscreen.self, forKey: .display)
            displayContent = .fullscreen(fullscreen)
        case .custom:
            let custom = try container.decode(AirshipJSON.self, forKey: .display)
            displayContent = .custom(custom)
        case .html:
            let html = try container.decode(InAppMessageDisplayContent.HTML.self, forKey: .display)
            displayContent = .html(html)
        case .layout:
            let wrapper = try container.decode(AirshipLayoutWrapper.self, forKey: .display)
            displayContent = .airshipLayout(wrapper.layout)
        }

        self.init(
            name: name,
            displayContent: displayContent,
            source: source,
            extras: extras,
            actions: actions,
            isReportingEnabled: isReportingEnabled,
            displayBehavior: displayBehavior,
            renderedLocale: renderedLocale
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encodeIfPresent(self.source, forKey: .source)
        try container.encodeIfPresent(self.extras, forKey: .extras)
        try container.encodeIfPresent(self.actions, forKey: .actions)
        try container.encodeIfPresent(self.isReportingEnabled, forKey: .isReportingEnabled)
        try container.encodeIfPresent(self.isReportingEnabled, forKey: .isReportingEnabled)
        try container.encodeIfPresent(self.displayBehavior, forKey: .displayBehavior)
        try container.encodeIfPresent(self.renderedLocale, forKey: .renderedLocale)

        switch (self.displayContent) {
        case .banner(let banner):
            try container.encode(banner, forKey: .display)
            try container.encode(DisplayType.banner, forKey: .displayType)
        case .fullscreen(let fullscreen):
            try container.encode(fullscreen, forKey: .display)
            try container.encode(DisplayType.fullscreen, forKey: .displayType)
        case .modal(let modal):
            try container.encode(modal, forKey: .display)
            try container.encode(DisplayType.modal, forKey: .displayType)
        case .html(let html):
            try container.encode(html, forKey: .display)
            try container.encode(DisplayType.html, forKey: .displayType)
        case .custom(let custom):
            try container.encode(custom, forKey: .display)
            try container.encode(DisplayType.custom, forKey: .displayType)
        case .airshipLayout(let layout):
            try container.encode(AirshipLayoutWrapper(layout: layout), forKey: .display)
            try container.encode(DisplayType.layout, forKey: .displayType)
        }
    }

    private enum DisplayType: String, Codable {
        case banner
        case modal
        case fullscreen
        case custom
        case html
        case layout
    }
}

extension InAppMessage {
    var urlInfos: [URLInfo] {
        switch (self.displayContent) {
        case .banner(let content):
            return urlInfosForMedia(content.media)
        case .fullscreen(let content):
            return urlInfosForMedia(content.media)
        case .modal(let content):
            return urlInfosForMedia(content.media)
        case .html(let html):
            return [.web(url: html.url, requireNetwork: html.requiresConnectivity != false)]
        case .custom(_):
            return []
        case .airshipLayout(let content):
            return content.urlInfos
        }
    }

    private func urlInfosForMedia(_ media: InAppMessageMediaInfo?) -> [URLInfo] {
        guard let media = media else {
            return []
        }

        switch (media.type) {
        case .image: return [.image(url: media.url, prefetch: true)]
        case .video: return [.video(url: media.url)]
        case .youtube: return [.video(url: media.url)]
        }
    }

    var isEmbedded: Bool {
        guard case .airshipLayout(let data) = self.displayContent else {
            return false
        }

        return data.isEmbedded
    }


    var isAirshipLayout: Bool {
        guard case .airshipLayout(_) = self.displayContent else {
            return false
        }

        return true
    }
}

fileprivate struct AirshipLayoutWrapper: Codable {
    var layout: AirshipLayout
}

/// These are just for view testing purposes
extension InAppMessage {
    /// We return a window since we are implementing display
    /// - Note: for internal use only.  :nodoc:
    @MainActor
    public func _display(
        scene: UIWindowScene
    ) async throws {
        let adapter = try AirshipLayoutDisplayAdapter(message: self, priority: 0, assets: EmptyAirshipCachedAssets())
        _ = try await adapter.display(
            scene: DefaultWindowSceneHolder(scene: scene),
            analytics: LoggingInAppMessageAnalytics()
        )
    }
}
