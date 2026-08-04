/* Copyright Airship and Contributors */

public import AirshipCore

extension AirshipAI {
    /// Namespace for the in-app message AI suppression usage.
    public enum InAppMessageSuppression {
        /// The AI usage key for in-app message suppression.
        ///
        /// Pass this to `Airship.ai.setContextProvider(_:for:)` when registering a context provider for
        /// in-app message suppression.
        public static let usage = AirshipAI.Usage<Subject>(rawValue: "in_app_message_suppression")

        /// The context subject passed to the app's registered context provider so it can return user
        /// context relevant to the specific message being considered. `hints` carries the schedule's
        /// `subject_hints` for the provider; it is never added to the prompt.
        public struct Subject: Sendable {
            /// Message name.
            public let name: String

            /// Flat string extras from the message.
            public let extras: AirshipJSON?

            /// The schedule priority (lower runs first).
            public let priority: Int

            /// Layout-authored hints (`subject_hints`) handed to the context provider. Not rendered
            /// into the prompt.
            public let hints: [String: String]

            public init(
                name: String,
                extras: AirshipJSON? = nil,
                priority: Int = 0,
                hints: [String: String] = [:]
            ) {
                self.name = name
                self.extras = extras
                self.priority = priority
                self.hints = hints
            }
        }
    }
}
