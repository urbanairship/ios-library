/* Copyright Airship and Contributors */

import AirshipAutomation
import AirshipBasement
import AirshipCore
import AirshipScenes
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
        Airship.ai.setDefaultContextProvider(DevDefaultContextProvider())

        // Bring-your-own-model testing: set ANTHROPIC_API_KEY or OPENAI_API_KEY in the
        // scheme's environment variables (Product > Scheme > Edit Scheme > Run > Arguments)
        // to route every usage to that provider instead of the on-device default.
        let environment = ProcessInfo.processInfo.environment
        if let apiKey = environment["ANTHROPIC_API_KEY"], !apiKey.isEmpty {
            let model = ClaudeAIModel(apiKey: apiKey)
            Airship.ai.setModelResolver { _ in .custom(model) }
        } else if let apiKey = environment["OPENAI_API_KEY"], !apiKey.isEmpty {
            let model = OpenAIModel(apiKey: apiKey)
            Airship.ai.setModelResolver { _ in .custom(model) }
        }
    }
}

private final class DevDefaultContextProvider: AirshipAI.ContextProvider {
    typealias Subject = Void

    func context(for subject: Void) async -> AirshipAI.Context {
        var items: [AirshipAI.Context.Item] = [
            .init(content: "User interests: cats"),
            .init(content: "Customer since: 2019"),
            .init(content: "Rental history: 15ft (2022), 20ft (2024)"),
        ]

        if let namedUser = await Airship.contact.namedUserID {
            items.append(.init(content: "Named user: \(namedUser)"))
        }

        let tags = Airship.channel.tags
        if !tags.isEmpty {
            items.append(.init(content: "Channel tags: \(tags.sorted().joined(separator: ", "))"))
        }

        let notifStatus = await Airship.push.notificationStatus
        items.append(.init(content: "Notifications opted in: \(notifStatus.isUserOptedIn)"))

        if let channelID = Airship.channel.identifier {
            items.append(.init(content: "Channel ID: \(channelID)"))
        }

        if let subscriptions = try? await Airship.contact.fetchSubscriptionLists(), !subscriptions.isEmpty {
            let rendered = subscriptions
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value.map(\.rawValue).joined(separator: ", "))" }
                .joined(separator: "; ")
            items.append(.init(content: "Contact subscriptions: \(rendered)"))
        }

        return AirshipAI.Context(items: items)
    }
}
