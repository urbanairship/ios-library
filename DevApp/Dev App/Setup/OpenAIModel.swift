/* Copyright Airship and Contributors */

import AirshipCore
import Foundation

/// Example `AirshipAI.Model` that routes on-device AI evaluations to OpenAI's Chat
/// Completions API.
///
/// - Note: This is an example - do not ship an API key embedded in a real app. Proxy the
///   request through your own backend instead. Reads its key from the `OPENAI_API_KEY`
///   environment variable (Scheme > Run > Arguments > Environment Variables) so it never
///   gets committed.
struct OpenAIModel: AirshipAI.Model {
    let apiKey: String

    // availability, availabilityUpdates, maxAttempts and responseTimeout all have
    // protocol defaults that suit a network-backed model, so respond(_:) is the
    // only requirement.

    func respond(_ request: AirshipAI.Request) async throws -> AirshipJSON {
        let body: [String: Any] = [
            "model": "gpt-4o",
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "airship_ai_response",
                    "strict": true,
                    "schema": try Self.strictSchema(request.schema),
                ],
            ],
            "messages": [
                ["role": "system", "content": request.instructions],
                ["role": "user", "content": request.prompt()],
            ],
        ]

        var urlRequest = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw OpenAIModelError.requestFailed(status: http.statusCode, body: body)
        }

        let completion = try JSONDecoder().decode(OpenAICompletion.self, from: data)

        guard
            let content = completion.choices.first?.message.content,
            let contentData = content.data(using: .utf8)
        else {
            throw OpenAIModelError.noContent
        }

        return try JSONDecoder().decode(AirshipJSON.self, from: contentData)
    }

    /// Converts an `AirshipJSONSchema` into the strict JSON Schema shape OpenAI requires:
    /// every object gets `additionalProperties: false`, every property is listed in
    /// `required`, and properties that were originally optional become nullable instead.
    private static func strictSchema(_ schema: AirshipJSONSchema) throws -> Any {
        toStrict(try JSONSerialization.jsonObject(with: try JSONEncoder().encode(schema)))
    }

    private static func toStrict(_ node: Any) -> Any {
        guard var object = node as? [String: Any] else {
            if let array = node as? [Any] { return array.map(toStrict) }
            return node
        }
        if object["type"] as? String == "object" {
            let properties = object["properties"] as? [String: Any] ?? [:]
            let required = Set(object["required"] as? [String] ?? [])
            var newProperties: [String: Any] = [:]
            for (key, value) in properties {
                let converted = toStrict(value)
                newProperties[key] = required.contains(key) ? converted : nullable(converted)
            }
            object["properties"] = newProperties
            object["required"] = Array(properties.keys)
            object["additionalProperties"] = false
        }
        if let items = object["items"] {
            object["items"] = toStrict(items)
        }
        return object
    }

    private static func nullable(_ schema: Any) -> Any {
        guard var object = schema as? [String: Any], let type = object["type"] as? String else {
            return schema
        }
        object["type"] = [type, "null"]
        return object
    }
}

private struct OpenAICompletion: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message
    }
    let choices: [Choice]
}

private enum OpenAIModelError: Error {
    case noContent
    case requestFailed(status: Int, body: String)
}
