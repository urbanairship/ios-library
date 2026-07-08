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
        var attributes: [String: AirshipJSON] = [:]

        if let namedUser = await Airship.contact.namedUserID {
            attributes["named_user"] = .string(namedUser)
        }

        let tags = Airship.channel.tags
        if !tags.isEmpty {
            attributes["channel_tags"] = .array(tags.sorted().map { .string($0) })
        }

        if let channelID = Airship.channel.identifier {
            attributes["channel_id"] = .string(channelID)
        }

        let notifStatus = await Airship.push.notificationStatus
        attributes["notifications_opted_in"] = .bool(notifStatus.isUserOptedIn)

        if let subscriptions = try? await Airship.contact.fetchSubscriptionLists(), !subscriptions.isEmpty {
            let encoded = subscriptions.sorted { $0.key < $1.key }.reduce(into: [String: AirshipJSON]()) { result, entry in
                result[entry.key] = .array(entry.value.map { .string($0.rawValue) })
            }
            attributes["contact_subscriptions"] = .object(encoded)
        }

        return AirshipAI.Context(attributes: attributes)
    }
}
