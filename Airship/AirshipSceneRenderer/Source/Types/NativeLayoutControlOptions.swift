/* Copyright Airship and Contributors */

import Foundation

/// Layout-level options for native layouts (e.g. state restoration across displays).
/// - Note: For internal use only. :nodoc:
public struct NativeLayoutControlOptions {

    /// When set, controls restoring state across displays.
    /// - Note: For internal use only. :nodoc:
    public let stateRestoration: StateRestoration?

    /// Controls restoring state across displays.
    /// - Note: For internal use only. :nodoc:
    public struct StateRestoration: ThomasSerializable {

        /// How state is scoped when restoring.
        public var scope: Scope

        /// If this value changes between displays, state is reset.
        public var restoreID: String

        /// Scope for restored state.
        ///
        /// - `instance`: Scoped to the message instance (Message Center: tied to message delivery;
        ///   IAX: tied to the automation/schedule). State is not shared across different instances
        ///   even if layouts share a `restore_id`.
        /// - Note: For internal use only. :nodoc:
        public enum Scope: String, ThomasSerializable {
            case instance
        }

        private enum CodingKeys: String, CodingKey {
            case scope
            case restoreID = "restore_id"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case stateRestoration = "state_restoration"
    }
}

extension NativeLayoutControlOptions: ThomasSerializable {}
