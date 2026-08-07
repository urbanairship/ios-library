/* Copyright Airship and Contributors */

import AirshipCore
import Foundation

/// Example `AirshipAI.Model` that routes on-device AI evaluations to Anthropic's Claude API.
///
/// - Note: This is an example - do not ship an API key embedded in a real app. Proxy the
///   request through your own backend instead. Reads its key from the `ANTHROPIC_API_KEY`
///   environment variable (Scheme > Run > Arguments > Environment Variables) so it never
///   gets committed.
struct ClaudeAIModel: AirshipAI.Model {
    let apiKey: String

    // availability, availabilityUpdates, maxAttempts and responseTimeout all have
    // protocol defaults that suit a network-backed model, so respond(_:) is the
    // only requirement.

    func respond(_ request: AirshipAI.Request) async throws -> AirshipJSON {
        let body: [String: Any] = [
            "model": "claude-opus-5",
            "max_tokens": 1024,
            "system": request.instructions,
            "messages": [["role": "user", "content": request.prompt()]],
            "output_config": [
                "format": [
                    "type": "json_schema",
                    "schema": try Self.encodedSchema(request.schema),
                ]
            ],
        ]

        var urlRequest = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ClaudeAIModelError.requestFailed(status: http.statusCode, body: body)
        }

        let message = try JSONDecoder().decode(ClaudeMessage.self, from: data)

        guard
            let text = message.content.first(where: { $0.type == "text" })?.text,
            let textData = text.data(using: .utf8)
        else {
            throw ClaudeAIModelError.noTextContent
        }

        return try JSONDecoder().decode(AirshipJSON.self, from: textData)
    }

    /// Converts an `AirshipJSONSchema` into a plain JSON Schema object and adds
    /// `additionalProperties: false` to every object node, which Claude's structured
    /// outputs require but `AirshipJSONSchema`'s encoding doesn't include.
    private static func encodedSchema(_ schema: AirshipJSONSchema) throws -> Any {
        let object = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(schema))
        return addingAdditionalPropertiesFalse(to: object)
    }

    private static func addingAdditionalPropertiesFalse(to node: Any) -> Any {
        if var object = node as? [String: Any] {
            if object["type"] as? String == "object" {
                object["additionalProperties"] = false
            }
            for (key, value) in object {
                object[key] = addingAdditionalPropertiesFalse(to: value)
            }
            return object
        }
        if let array = node as? [Any] {
            return array.map(addingAdditionalPropertiesFalse)
        }
        return node
    }
}

private struct ClaudeMessage: Decodable {
    struct Block: Decodable {
        let type: String
        let text: String?
    }
    let content: [Block]
}

private enum ClaudeAIModelError: Error {
    case noTextContent
    case requestFailed(status: Int, body: String)
}
