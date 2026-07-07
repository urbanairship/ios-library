/* Copyright Airship and Contributors */

import Foundation

extension AirshipAI {
    final class SchemaRegistry: Sendable {

        @MainActor
        private var schemas: [Usage: Schema] = [:]

        init() {}

        @MainActor
        func setSchema(_ schema: Schema, for usage: Usage) {
            schemas[usage] = schema
        }

        @MainActor
        func schema(for usage: Usage) -> Schema? {
            schemas[usage]
        }
    }
}
