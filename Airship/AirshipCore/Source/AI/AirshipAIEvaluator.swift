/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipBasement

extension AirshipAI {
    struct Evaluator {

        func evaluate<E: Evaluation>(
            _ evaluation: E,
            model: any Model,
            provider: (any ContextProvider)?,
            schema: Schema
        ) async -> Result<E.Output> {
            guard case .available = model.availability else {
                return .skipped(reason: "On-device model unavailable")
            }

            let context = await provider?.context(for: evaluation.usage) ?? .empty

            do {
                let json = try await model.respond(
                    instructions: evaluation.instructions(),
                    prompt: evaluation.prompt(context: context),
                    schema: schema
                )
                let output = try JSONDecoder().decode(E.Output.self, from: Data(json.utf8))
                return .completed(output)
            } catch {
                AirshipLogger.warn("AI evaluation failed for \(evaluation.usage): \(error)")
                return .failed(error)
            }
        }
    }
}
