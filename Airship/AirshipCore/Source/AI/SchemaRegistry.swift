/* Copyright Airship and Contributors */

import Foundation

extension AirshipAI {
    final class SchemaRegistry: Sendable {

        @MainActor
        private var schemas: [String: Schema] = [:]

        init() {}

        @MainActor
        func setSchema<S: Sendable>(_ schema: Schema, for usage: Usage<S>) {
            schemas[usage.rawValue] = schema
        }

        @MainActor
        func schema(for rawValue: String) -> Schema? {
            schemas[rawValue]
        }

        @MainActor
        var registeredUsageKeys: [String] {
            Array(schemas.keys)
        }
    }
}
