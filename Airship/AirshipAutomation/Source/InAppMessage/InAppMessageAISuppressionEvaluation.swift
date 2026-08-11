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

    public typealias Subject = AirshipAI.InAppMessageSuppression.Subject

    private let condition: String
    public let subject: AirshipAI.InAppMessageSuppression.Subject
    public let usage: AirshipAI.Usage<AirshipAI.InAppMessageSuppression.Subject> = AirshipAI.InAppMessageSuppression.usage

    public init(
        condition: String,
        subject: AirshipAI.InAppMessageSuppression.Subject
    ) {
        self.condition = condition
        self.subject = subject
    }

    public func instructions() -> String {
        """
        You are a gate that decides whether to show a single in-app message to the current \
        user. Show the message only when this condition holds for the user; otherwise do not \
        show it:

        <condition>\(condition)</condition>

        Decide using only the user context and attributes given in the prompt, reasoning \
        about what those signals imply rather than matching them literally. Set allow=true \
        to show the message and allow=false to hide it.

        - Set allow=false only when the context contains a signal that clearly contradicts \
        the condition (for example, the user's stated interests or behavior are directly at \
        odds with it).
        - In every other case — including when the context is missing, silent, or only \
        weakly related to the condition — set allow=true. Do not invent facts, and do not \
        treat the mere absence of a signal as proof the condition is unmet.

        Consider only this condition; ignore unrelated context.
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

        if let bullets = context.renderBullets() {
            parts.append("User context:\n\(bullets)")
        }

        return parts.joined(separator: "\n\n")
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
