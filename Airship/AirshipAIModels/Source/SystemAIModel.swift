/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipImport) import AirshipCore
@_spi(AirshipInternal) import AirshipBasement

extension String {
    var strippingCodeFence: String {
        var s = trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.hasPrefix("```") else { return s }
        // drop opening fence line (e.g. ```json\n)
        if let newline = s.firstIndex(of: "\n") {
            s = String(s[s.index(after: newline)...])
        }
        // drop closing fence
        if s.hasSuffix("```") {
            s = String(s.dropLast(3))
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

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
    ) async throws -> AirshipJSON {
        return try await withRetry {
            // A fresh session per attempt so a retry is an independent judgment rather
            // than a continuation of the previous (failed) turn's transcript.
            let session = LanguageModelSession(instructions: instructions)
            let content = try await session.respond(to: prompt + "\n\n" + schema.instruction).content.strippingCodeFence
            guard let data = content.data(using: .utf8) else {
                throw AirshipErrors.error("Model returned non-UTF8 content")
            }
            return try JSONDecoder().decode(AirshipJSON.self, from: data)
        }
    }

    private func withRetry<T: Sendable>(
        maxAttempts: Int = 3,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: (any Error)?
        for attempt in 1...maxAttempts {
            try Task.checkCancellation()
            do {
                return try await operation()
            } catch {
                lastError = error
                AirshipLogger.warn("SystemAIModel attempt \(attempt)/\(maxAttempts) failed: \(error)")
            }
        }
        throw lastError!
    }
}

#endif
