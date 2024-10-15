/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
public import AirshipCore
#endif

/// Landing page action
public final class LandingPageAction: AirshipAction {

    private static let productID: String = "landing_page"
    private static let queue: String = "landing_page"
    
    /// Landing page action names.
    public static let defaultNames: [String] = ["landing_page_action", "^p"]

    /// Schedule extender block.
    public typealias ScheduleExtender = @Sendable (ActionArguments, inout AutomationSchedule) -> Void

    private let borderRadius: Double
    private let scheduleExtender: ScheduleExtender?
    private let allowListChecker: @Sendable (URL) -> Bool
    private let scheduler: @Sendable (AutomationSchedule) async throws -> Void

    /// Default constructor
    /// - Parameters:
    ///     - borderRadius: Optional border radius in points. Defaults to 2.
    ///     - scheduleExtender: Optional extender. Can be used to modify the landing page action schedule.
    public convenience init(
        borderRadius: Double = 2.0,
        scheduleExtender: ScheduleExtender? = nil
    ) {
        self.init(
            borderRadius: borderRadius,
            scheduleExtender: scheduleExtender,
            allowListChecker: { Airship.urlAllowList.isAllowed($0, scope: .openURL) },
            scheduler: { try await InAppAutomation.shared.upsertSchedules([$0]) }
        )
    }

    init(
        borderRadius: Double,
        scheduleExtender: ScheduleExtender?,
        allowListChecker: @escaping @Sendable (URL) -> Bool,
        scheduler: @escaping @Sendable (AutomationSchedule) async throws -> Void
    ) {
        self.borderRadius = borderRadius
        self.scheduleExtender = scheduleExtender
        self.allowListChecker = allowListChecker
        self.scheduler = scheduler
    }

    public func accepts(arguments: ActionArguments) async -> Bool {
        switch(arguments.situation) {
        case .manualInvocation: return true
        case .launchedFromPush: return true
        case .foregroundPush: return true
        case .backgroundPush: return false
        case .webViewInvocation: return true
        case .foregroundInteractiveButton: return true
        case .backgroundInteractiveButton: return false
        case .automation: return true
#if canImport(AirshipCore)
        @unknown default:
            return false
#endif
        }
    }

    public func perform(arguments: ActionArguments) async throws -> AirshipJSON? {
        let pushMetadata = arguments.metadata[ActionArguments.pushPayloadJSONMetadataKey] as? AirshipJSON
        let messageID = pushMetadata?.object?["_"]?.string
        let args: LandingPageArgs = try arguments.value.decode()

        guard self.allowListChecker(args.url) else {
            throw AirshipErrors.error("Landing page URL not allowed \(args.url)")
        }

        let message = InAppMessage(
            name: "Landing Page \(args.url)",
            displayContent: .html(
                .init(
                    url: args.url.absoluteString,
                    height: args.height,
                    width: args.width,
                    aspectLock: args.aspectLock,
                    requiresConnectivity: false,
                    borderRadius: self.borderRadius
                )
            ),
            isReportingEnabled: messageID != nil,
            displayBehavior: .immediate
        )

        var schedule = AutomationSchedule(
            identifier: messageID ?? UUID().uuidString,
            data: .inAppMessage(message),
            triggers: [AutomationTrigger.activeSession(count: 1)],
            priority: Int.min,
            bypassHoldoutGroups: true,
            productID: Self.productID,
            queue: Self.queue
        )

        self.scheduleExtender?(arguments, &schedule)
        try await self.scheduler(schedule)
        return nil
    }

    fileprivate struct LandingPageArgs: Decodable, Sendable {
        var url: URL
        var height: Double?
        var width: Double?
        var aspectLock: Bool?

        enum CodingKeys: String, CodingKey {
            case url
            case height
            case width
            case aspectLock = "aspect_lock"
            case aspectLockLegacy = "aspectLock"
        }

        init(from decoder: Decoder) throws {
            do {
                let container: KeyedDecodingContainer<Self.CodingKeys> = try decoder.container(keyedBy: Self.CodingKeys.self)
                self.url = try Self.parseURL(
                    string: try container.decode(String.self, forKey: CodingKeys.url)
                )

                self.height = try container.decodeIfPresent(Double.self, forKey: CodingKeys.height)
                self.width = try container.decodeIfPresent(Double.self, forKey: CodingKeys.width)
                self.aspectLock = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.aspectLock)
            } catch {
                let container = try decoder.singleValueContainer()
                self.url = try Self.parseURL(
                    string: try container.decode(String.self)
                )
                self.height = nil
                self.width = nil
                self.aspectLock = nil
            }
        }

        private static func parseURL(string: String) throws -> URL {
            guard let url = URL(string: string) else {
                throw AirshipErrors.error("Invalid URL \(string)")
            }

            if !url.absoluteString.isEmpty, url.scheme?.isEmpty ?? true {
                return URL(string: "https://" + string) ?? url
            }

            return url
        }
    }
}
