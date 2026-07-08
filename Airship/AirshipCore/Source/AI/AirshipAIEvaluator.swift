/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipBasement

extension AirshipAI {
    struct Evaluator {

        func evaluate<E: Evaluation>(
            _ evaluation: E,
            model: any Model,
            context: Context,
            schema: Schema
        ) async -> Result<E.Output> {
            guard case .available = model.availability else {
                return .skipped(reason: "On-device model unavailable")
            }

            do {
                let instructions = evaluation.instructions()
                let prompt = evaluation.prompt(context: context)
                AirshipLogger.debug("AI evaluate [\(evaluation.usage.rawValue)] instructions:\n\(instructions)\n\nschema:\n\(schema.instruction)\n\nprompt:\n\(prompt)")
                let json = try await model.respond(
                    instructions: instructions,
                    prompt: prompt,
                    schema: schema
                )
                AirshipLogger.debug("AI evaluate [\(evaluation.usage.rawValue)] response:\n\(json)")
                let output: E.Output = try json.decode()
                return .completed(output)
            } catch {
                AirshipLogger.warn("AI evaluation failed for \(evaluation.usage.rawValue): \(error)")
                return .failed(error)
            }
        }
    }
}
