/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// In-App Message
public struct InAppMessage: Codable, Equatable, Sendable {

    /// Display behavior
    public enum DisplayBehavior: String, Codable, Equatable, Sendable {
        /// Immediate display, allows it to be dispalyed on top of other IAX
        case immediate

        /// Displays one at a time with display interval between displays
        case standard
    }

    enum Source: String, Codable, Equatable {
        case remoteData = "remote-data"
        case appDefined = "app-defined"
        case legacyPush = "legacy-push"
    }

    /// The name.
    public var name: String

    /// Display content
    public var displayContent: InAppMessageDisplayContent

    /// Source
    var source: Source?

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
        case extras
        case actions
        case isReportingEnabled = "reporting_enabled"
        case displayBehavior = "display_behavior"
        case display
        case displayType = "display_type"
        case renderedLocale = "rendered_locale"
        case source
    }

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
        source: Source?,
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
        self.renderedLocale = nil

    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let name = try container.decode(String.self, forKey: .name)
        let source = try container.decodeIfPresent(Source.self, forKey: .source)
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
            let layout = try container.decode(AirshipJSON.self, forKey: .display)
            displayContent = .airshipLayout(layout)
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
            try container.encode(layout, forKey: .display)
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
