/* Copyright Airship and Contributors */

@_spi(AirshipInternal) public import AirshipCore
import Foundation


@_spi(AirshipInternal)
public struct InAppMessageFilterEvaluation: AirshipAI.Evaluation {
    public struct Output: Decodable, Sendable {
        public let allow: Bool
        public let reason: String
    }

    public static let schema = AirshipAI.Schema(fields: [
        .init(name: "allow", type: .boolean, description: "Whether to show the in-app message to this user"),
        .init(name: "reason", type: .string, description: "Brief reason for the decision"),
    ])

    public typealias Subject = InAppMessageFilterContext

    private let filterPrompt: String
    public let subject: InAppMessageFilterContext
    public let usage: AirshipAI.Usage<InAppMessageFilterContext> = InAppMessageFilterContext.filterUsage

    public init(
        filterPrompt: String,
        subject: InAppMessageFilterContext
    ) {
        self.filterPrompt = filterPrompt
        self.subject = subject
    }

    public func instructions() -> String {
        """
        You decide whether an in-app message is relevant to the current user based on \
        their context. Return allow=true if the message is worth showing, allow=false if \
        it is clearly irrelevant or redundant given what you know about the user. When in \
        doubt, allow the message — it is better to show a marginally relevant message than \
        to suppress one the user would have wanted.
        """
    }

    public func prompt(context: AirshipAI.Context) -> String {
        var parts: [String] = ["Message name: \(subject.name)"]

        if !filterPrompt.isEmpty {
            parts.append("Filter instruction: \(filterPrompt)")
        }

        if let extras = subject.extras, extras != .null,
           let formatted = extras.promptString, formatted != "{}" {
            parts.append("Message Extras: \(formatted)")
        }

        if let campaigns = subject.campaigns, campaigns != .null,
           let formatted = campaigns.promptString, formatted != "{}" {
            parts.append("Campaigns: \(formatted)")
        }

        if let summary = context.summary {
            parts.append("User context: \(summary)")
        }

        if !context.attributes.isEmpty,
           let formatted = AirshipJSON.object(context.attributes).promptString, formatted != "{}" {
            parts.append("User attributes: \(formatted)")
        }

        return parts.joined(separator: "\n")
    }
}

fileprivate extension AirshipJSON {
    var promptString: String? {
        do {
            return try self.toString()
        } catch {
            AirshipLogger.error("IAA filter: failed to serialize AirshipJSON: \(error)")
            return nil
        }
    }
}
