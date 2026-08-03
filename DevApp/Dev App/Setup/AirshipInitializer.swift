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
        Airship.ai.setContextProvider(DevIAASuppressionContextProvider(), for: InAppMessageAISuppression.usage)
        Airship.ai.setContextProvider(DevSceneTextInputContextProvider(), for: SceneTextInputInferenceSubject.inferenceUsage)

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

private final class DevSceneTextInputContextProvider: AirshipAI.ContextProvider {
    typealias Subject = SceneTextInputInferenceSubject

    func context(for subject: SceneTextInputInferenceSubject) async -> AirshipAI.Context {
        // Demo context: profile data relevant to truck size selection.
        // A real app would pull these from its customer profile API.
        return AirshipAI.Context(items: [
            .init(content: "Customer since: 2019"),
            .init(content: "Rental history: 15ft (2022), 20ft (2024)"),
        ])
    }
}

private final class DevIAASuppressionContextProvider: AirshipAI.ContextProvider {
    typealias Subject = InAppMessageAISuppression

    func context(for subject: InAppMessageAISuppression) async -> AirshipAI.Context {
        var items: [AirshipAI.Context.Item] = []

        // Layout-authored subject_hints are handed to the provider (never the prompt) so
        // the app can tailor context to them.
        for (key, value) in subject.hints.sorted(by: { $0.key < $1.key }) {
            items.append(.init(content: "\(key): \(value)"))
        }

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
