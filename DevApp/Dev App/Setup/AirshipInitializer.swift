/* Copyright Airship and Contributors */

import AirshipAutomation
import AirshipBasement
import AirshipCore
import Foundation

/// Example Airship SDK initialization handler.
///
/// This is a sample implementation showing how to configure and initialize
/// the Airship SDK with basic settings for development and production builds.
///
/// - Note: This is an example - customize for your app's needs.
struct AirshipInitializer {

    private init() {}

    /// Initializes Airship with example configuration.
    ///
    /// - Throws: An error if Airship initialization fails
    @MainActor
    static func initialize() throws {
        var config = try AirshipConfig.default()
        config.productionLogLevel = .verbose
        config.developmentLogLevel = .verbose

        #if DEBUG
        config.inProduction = false
        config.isAirshipDebugEnabled = true
        config.isWebViewInspectionEnabled = true
        #else
        config.inProduction = true
        #endif

        try Airship.takeOff(config)

        Airship.ai.setProvider(DevIAAFilterContextProvider(), for: InAppMessageFilterContext.filterUsage)
    }
}

private final class DevIAAFilterContextProvider: AirshipAI.ContextProvider {
    typealias Subject = InAppMessageFilterContext

    func context(for subject: InAppMessageFilterContext) async -> AirshipAI.Context {
        var items: [AirshipAI.Context.Item] = []

        if let namedUser = await Airship.contact.namedUserID {
            items.append(.init(content: "Named user: \(namedUser)", priority: .high))
        }

        let tags = Airship.channel.tags
        if !tags.isEmpty {
            items.append(.init(content: "Channel tags: \(tags.sorted().joined(separator: ", "))", priority: .medium))
        }

        let notifStatus = await Airship.push.notificationStatus
        items.append(.init(content: "Notifications opted in: \(notifStatus.isUserOptedIn)", priority: .medium))

        if let channelID = Airship.channel.identifier {
            items.append(.init(content: "Channel ID: \(channelID)", priority: .low))
        }

        if let subscriptions = try? await Airship.contact.fetchSubscriptionLists(), !subscriptions.isEmpty {
            let rendered = subscriptions
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value.map(\.rawValue).joined(separator: ", "))" }
                .joined(separator: "; ")
            items.append(.init(content: "Contact subscriptions: \(rendered)", priority: .low))
        }

        return AirshipAI.Context(items: items)
    }
}
