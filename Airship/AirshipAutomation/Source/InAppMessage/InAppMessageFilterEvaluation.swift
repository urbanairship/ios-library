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
        guard !filterPrompt.isEmpty else {
            return """
            You decide whether to show an in-app message to the current user based on their \
            context. When in doubt, show it.
            """
        }
        return """
        You are a gate that decides whether to show a single in-app message to the current \
        user. Show the message only when this condition holds for the user; otherwise do not \
        show it:

        \(filterPrompt)

        Evaluate the condition against the user context and attributes given in the prompt, \
        reasoning about what those signals imply rather than matching them literally. Only \
        this condition governs the decision — do not treat unrelated context as a reason to \
        show or hide the message. If the context is genuinely insufficient to judge the \
        condition, show the message.
        """
    }

    public func prompt(context: AirshipAI.Context) -> String {
        // The filter condition is the governing rule and lives in instructions() — it is
        // deliberately not repeated here as context.
        var parts: [String] = ["Message name: \(subject.name)"]

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
