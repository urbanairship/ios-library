/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

#if canImport(AirshipBasement)
@_spi(AirshipInternal) import AirshipBasement
#endif

/// Scene page action
final class SceneAction: AirshipAction {

    private static let productID: String = "scene_page"
    private static let queue: String = "landing_page"

    /// Scene action names.
    public static let defaultNames: [String] = ["scene_action", "^sc"]

    /// Default predicate - rejects `ActionSituation.foregroundPush`
    public static let defaultPredicate: @Sendable (ActionArguments) -> Bool = { args in
        return args.situation != .foregroundPush
    }

    private let scheduler: @Sendable (AutomationSchedule) async throws -> Void

    public convenience init() {
        self.init(
            scheduler: { try await Airship.inAppAutomation.upsertSchedules([$0]) }
        )
    }

    init(
        scheduler: @escaping @Sendable (AutomationSchedule) async throws -> Void
    ) {
        self.scheduler = scheduler
    }

    public func accepts(arguments: ActionArguments) async -> Bool {
        switch arguments.situation {
        case .manualInvocation,
                .launchedFromPush,
                .foregroundPush,
                .webViewInvocation,
                .foregroundInteractiveButton,
                .automation:
            return true
        case .backgroundPush,
                .backgroundInteractiveButton:
            return false
#if canImport(AirshipCore)
        @unknown default:
            return false
#endif
        }
    }

    fileprivate struct ActionArgs: Decodable, Sendable {
        var dsl: String
    }

    @MainActor
    public func perform(arguments: ActionArguments) async throws -> AirshipJSON? {
        let pushMetadata = arguments.metadata[ActionArguments.pushPayloadJSONMetadataKey] as? AirshipJSON
        let messageID = pushMetadata?.object?["_"]?.string

        // Decode the action arguments object
        let args: ActionArgs = try arguments.value.decode()

        let layoutJSON = try SceneAction.layoutJSON(from: args.dsl)

        // The scene DSL contains the raw AirshipLayout. Wrap it under "layout" so it matches
        // the canonical display format that AirshipLayoutIntermediate and the remote-data path expect.
        let wrappedLayoutJSON = AirshipJSON.object(["layout": layoutJSON])

        let message = InAppMessage(
            name: "Scene Landing Page \(messageID ?? "")",
            displayContent: .airshipLayoutIntermediate(
                AirshipLayoutIntermediate(layoutJSON: wrappedLayoutJSON)
            ),
            isReportingEnabled: messageID != nil,
            displayBehavior: .immediate
        )

        let schedule = AutomationSchedule(
            identifier: messageID ?? UUID().uuidString,
            data: .inAppMessage(message),
            triggers: [AutomationTrigger.activeSession(count: 1)],
            priority: Int.min,
            bypassHoldoutGroups: true,
            productID: Self.productID,
            queue: Self.queue
        )

        try await self.scheduler(schedule)
        return nil
    }

    private static func layoutJSON(from base64Scene: String) throws -> AirshipJSON {
        guard let compressedData = AirshipBase64.data(from: base64Scene) else {
            throw AirshipErrors.error("Invalid base64 encoded scene string")
        }
        let decompressedData = try (compressedData as NSData).decompressed(using: .zlib) as Data
        return try AirshipJSON.from(data: decompressedData)
    }
}
