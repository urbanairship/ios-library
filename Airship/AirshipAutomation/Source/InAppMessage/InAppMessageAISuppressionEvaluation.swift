/* Copyright Airship and Contributors */

@_spi(AirshipInternal) public import AirshipCore
import Foundation


@_spi(AirshipInternal)
public struct InAppMessageAISuppressionEvaluation: AirshipAI.Evaluation {
    public struct Output: Decodable, Sendable {
        public let allow: Bool
        public let reason: String
    }

    public let schema: AirshipJSONSchema = AirshipJSONSchema.object(
        properties: [
            "allow": .boolean(description: "Whether to show the in-app message to this user"),
            "reason": .string(description: "Brief reason for the decision"),
        ],
        required: ["allow", "reason"]
    )

    public typealias Subject = InAppMessageAISuppression

    private let condition: String
    public let subject: InAppMessageAISuppression
    public let usage: AirshipAI.Usage<InAppMessageAISuppression> = InAppMessageAISuppression.usage

    public init(
        condition: String,
        subject: InAppMessageAISuppression
    ) {
        self.condition = condition
        self.subject = subject
    }

    public func instructions() -> String {
        guard !condition.isEmpty else {
            return """
            You decide whether to show an in-app message to the current user based on their \
            context. When in doubt, show it.
            """
        }
        return """
        You are a gate that decides whether to show a single in-app message to the current \
        user. Show the message only when this condition holds for the user; otherwise do not \
        show it:

        \(condition)

        Evaluate the condition against the user context and attributes given in the prompt, \
        reasoning about what those signals imply rather than matching them literally. Only \
        this condition governs the decision — do not treat unrelated context as a reason to \
        show or hide the message. If the context is genuinely insufficient to judge the \
        condition, show the message.
        """
    }

    public func prompt(context: AirshipAI.Context) -> String {
        // The condition is the governing rule and lives in instructions() — deliberately not
        // repeated here. `hints` are provider-only and never rendered.
        var parts: [String] = ["Message name: \(subject.name)"]

        if let extras = subject.extras, extras != .null,
           let formatted = extras.promptString, formatted != "{}" {
            parts.append("Message Extras: \(formatted)")
        }

        parts.append("Message priority: \(subject.priority)")

        if let rendered = context.render() {
            parts.append("User context:\n\(rendered)")
        }

        return parts.joined(separator: "\n")
    }
}

fileprivate extension AirshipJSON {
    var promptString: String? {
        do {
            return try self.toString()
        } catch {
            AirshipLogger.error("IAA suppression: failed to serialize AirshipJSON: \(error)")
            return nil
        }
    }
}
