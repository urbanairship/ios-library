/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipImport) import AirshipCore

#if canImport(FoundationModels)
import FoundationModels

/// Production `AirshipAI.Model` backed by Apple's on-device `SystemLanguageModel`.
///
/// This is the only file in the SDK that imports FoundationModels.
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
final class SystemAIModel: AirshipAI.Model {

    var availability: AirshipAI.Availability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .unavailable(reason: .deviceNotEligible)
            case .appleIntelligenceNotEnabled:
                return .unavailable(reason: .appleIntelligenceNotEnabled)
            case .modelNotReady:
                return .unavailable(reason: .modelNotReady)
            @unknown default:
                return .unavailable(reason: .unknown)
            }
        }
    }

    func respond(
        instructions: String,
        prompt: String,
        schema: AirshipAI.Schema
    ) async throws -> String {
        let session = LanguageModelSession(
            instructions: instructions + "\n\n" + schema.instruction
        )
        let response = try await session.respond(to: prompt)
        return response.content
    }
}

#endif
