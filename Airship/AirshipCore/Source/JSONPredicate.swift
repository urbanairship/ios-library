/* Copyright Airship and Contributors */

/// Defines a predicate for evaluating a JSON payload.
///
/// `JSONPredicate` can be used to build complex logical conditions (`AND`, `OR`, `NOT`)
/// composed of multiple `JSONMatcher` objects.
public final class JSONPredicate: NSObject, Sendable, Codable {
    /// Key for the 'AND' logical operator.
    private static let andTypeKey = "and"
    /// Key for the 'OR' logical operator.
    private static let orTypeKey = "or"
    /// Key for the 'NOT' logical operator.
    private static let notTypeKey = "not"

    /// The type of logical operation (e.g., "and", "or", "not").
    private let type: String?

    /// The collection of sub-predicates for logical operations.
    private let subpredicates: [JSONPredicate]?

    /// The matcher to apply if this is a leaf predicate.
    private let jsonMatcher: JSONMatcher?

    /// Designated initializer.
    required init(
        type: String?,
        jsonMatcher: JSONMatcher?,
        subpredicates: [JSONPredicate]?
    ) {
        self.type = type
        self.jsonMatcher = jsonMatcher
        self.subpredicates = subpredicates
        super.init()
    }

    /// Coding keys for serialization.
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case keyAnd = "and"
        case keyOr = "or"
        case keyNot = "not"
    }

    /// Creates a new predicate from a JSON payload.
    ///
    /// - Parameter json: The JSON payload representing the predicate.
    /// - Throws: An error if the JSON is invalid or cannot be decoded.
    public convenience init(json: Any?) throws {
        let value: JSONPredicate = try AirshipJSON.wrap(json).decode()
        self.init(type: value.type, jsonMatcher: value.jsonMatcher, subpredicates: value.subpredicates)
    }

    /// - Note: For internal use only. :nodoc:
    public convenience init(from decoder: any Decoder) throws {
        // This implementation is for backward compatibility and may be refactored.
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let key = CodingKeys.allCases.first(where: { container.contains($0) }) {
            let subpredicates: [JSONPredicate]

            if key == CodingKeys.keyNot {
                // Handle 'not' which can contain a single predicate or an array with one predicate
                if let singlePredicate = try? container.decode(JSONPredicate.self, forKey: key) {
                    subpredicates = [singlePredicate]
                } else {
                    let predicates = try container.decode([JSONPredicate].self, forKey: key)
                    guard predicates.count == 1 else {
                        throw AirshipErrors.error("A `not` predicate must contain a single sub-predicate.")
                    }
                    subpredicates = predicates
                }
            } else {
                subpredicates = try container.decode([JSONPredicate].self, forKey: key)
            }

            self.init(
                type: key.rawValue,
                jsonMatcher: nil,
                subpredicates: subpredicates
            )
        } else {
            let matcher = try decoder.singleValueContainer().decode(JSONMatcher.self)
            self.init(jsonMatcher: matcher)
        }
    }

    /// - Note: For internal use only. :nodoc:
    public func encode(to encoder: any Encoder) throws {
        if let jsonMatcher {
            var container = encoder.singleValueContainer()
            try container.encode(jsonMatcher)
            return
        }

        var container = encoder.container(keyedBy: CodingKeys.self)
        let key: CodingKeys
        switch(type) {
        case CodingKeys.keyAnd.rawValue: key = .keyAnd
        case CodingKeys.keyOr.rawValue: key = .keyOr
        case CodingKeys.keyNot.rawValue: key = .keyNot
        default: throw AirshipErrors.error("Invalid predicate type \(type ?? "n/a")")
        }

        try container.encodeIfPresent(self.subpredicates, forKey: key)
    }

    /// Returns the predicate's JSON payload representation.
    /// - Returns: A `[String: Any]` dictionary representing the predicate.
    @available(*, deprecated, message: "Use Codable conformance for serialization instead.")
    public func payload() -> [String: Any] {
        return (try? AirshipJSON.wrap(self).unWrap() as? [String: Any]) ?? [:]
    }

    /// Evaluates the given `AirshipJSON` value against the predicate.
    /// - Parameter json: The `AirshipJSON` object to evaluate.
    /// - Returns: `true` if the value matches the predicate; otherwise, `false`.
    public func evaluate(json: AirshipJSON) -> Bool {
        switch type {
        case JSONPredicate.andTypeKey:
            // All sub-predicates must be true
            return subpredicates?.allSatisfy { $0.evaluate(json: json) } ?? true
        case JSONPredicate.orTypeKey:
            // At least one sub-predicate must be true
            return subpredicates?.contains { $0.evaluate(json: json) } ?? false
        case JSONPredicate.notTypeKey:
            // The single sub-predicate must be false
            return !(subpredicates?.first?.evaluate(json: json) ?? false)
        default:
            // Evaluate using the JSON matcher
            return jsonMatcher?.evaluate(json: json) ?? false
        }
    }

    /// Evaluates the given object against the predicate.
    /// - Parameter object: The object to evaluate.
    /// - Returns: `true` if the predicate matches the object; otherwise, `false`.
    @available(*, deprecated, message: "Use evaluate(json:) instead")
    public func evaluate(_ object: Any?) -> Bool {
        do {
            return evaluate(json: try .wrap(object))
        } catch {
            AirshipLogger.error("Failed to evaluate json: \(error)")
            return false
        }
    }

    /// Creates a predicate from a `JSONMatcher`.
    /// - Parameter matcher: The `JSONMatcher` to base the predicate on.
    public convenience init(jsonMatcher matcher: JSONMatcher) {
        self.init(type: nil, jsonMatcher: matcher, subpredicates: nil)
    }

    /// Creates a predicate by AND-ing an array of sub-predicates.
    /// - Parameter subpredicates: An array of predicates to combine.
    /// - Returns: A new `JSONPredicate` instance.
    public class func andPredicate(subpredicates: [JSONPredicate]) -> JSONPredicate {
        return JSONPredicate(
            type: JSONPredicate.andTypeKey,
            jsonMatcher: nil,
            subpredicates: subpredicates
        )
    }

    /// Creates a predicate by OR-ing an array of sub-predicates.
    /// - Parameter subpredicates: An array of predicates to combine.
    /// - Returns: A new `JSONPredicate` instance.
    public class func orPredicate(subpredicates: [JSONPredicate]) -> JSONPredicate {
        return JSONPredicate(
            type: JSONPredicate.orTypeKey,
            jsonMatcher: nil,
            subpredicates: subpredicates
        )
    }

    /// Creates a predicate by NOT-ing a single sub-predicate.
    /// - Parameter subpredicate: The predicate to negate.
    /// - Returns: A new `JSONPredicate` instance.
    public class func notPredicate(subpredicate: JSONPredicate) -> JSONPredicate {
        return JSONPredicate(
            type: JSONPredicate.notTypeKey,
            jsonMatcher: nil,
            subpredicates: [subpredicate]
        )
    }

    /// Creates a predicate from a JSON payload.
    /// - Parameter json: The JSON payload.
    /// - Returns: A predicate or `nil` if the JSON is invalid.
    /// - Throws: An error if the JSON cannot be parsed.
    class func fromJson(json: Any?) throws -> JSONPredicate {
        return try JSONPredicate(json: json)
    }

    /// - Note: For internal use only. :nodoc:
    func isEqual(to predicate: JSONPredicate) -> Bool {
        return type == predicate.type
            && jsonMatcher == predicate.jsonMatcher
            && subpredicates == predicate.subpredicates
    }

    /// - Note: For internal use only. :nodoc:
    public override func isEqual(_ object: Any?) -> Bool {
        guard let predicate = object as? JSONPredicate else {
            return false
        }

        if self === predicate {
            return true
        }

        return isEqual(to: predicate)
    }

    /// - Note: For internal use only. :nodoc:
    public override var hash: Int {
        var hasher = Hasher()
        hasher.combine(type)
        hasher.combine(jsonMatcher)
        hasher.combine(subpredicates)
        return hasher.finalize()
    }
}
