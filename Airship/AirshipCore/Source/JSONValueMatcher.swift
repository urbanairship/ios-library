// Copyright Airship and Contributors

import Foundation

/// A `JSONValueMatcher` is used to match a JSON value against a set of constraints.
///
/// This class provides a flexible way to define conditions for JSON values, such as checking for equality,
/// numerical ranges, presence of a value, version constraints, and conditions on array elements.
/// It is `Codable`, allowing it to be easily serialized and deserialized.
public final class JSONValueMatcher: NSObject, Sendable, Codable {

    /// A protocol for defining the specific logic of a JSON value matcher.
    /// Each predicate implementation checks a JSON value against a specific condition.
    public protocol Predicate: Codable, Sendable, Hashable, Equatable {
        /// Evaluates the predicate against a given JSON value.
        /// - Parameters:
        ///   - json: The `AirshipJSON` value to evaluate.
        ///   - ignoreCase: If `true`, string comparisons will be case-insensitive.
        /// - Returns: `true` if the JSON value matches the predicate's conditions, otherwise `false`.
        func evaluate(json: AirshipJSON, ignoreCase: Bool) -> Bool

        /// Checks if this predicate is equal to another predicate.
        /// - Parameter other: The other predicate to compare against.
        /// - Returns: `true` if the predicates are equal, otherwise `false`.
        func isEqual(to other: any Predicate) -> Bool
    }

    private let predicate: any Predicate

    public init(from decoder: any Decoder) throws {
        // Decode the predicate using a helper function to avoid compiler timeouts.
        guard let predicate = Self.decodePredicate(from: decoder) else {
            throw AirshipErrors.parseError("Unsupported JSONValueMatcher predicate")
        }
        self.predicate = predicate
    }

    /// A helper function to decode one of the possible predicate types.
    private static func decodePredicate(from decoder: any Decoder) -> (any JSONValueMatcher.Predicate)? {
        // The decoding order matters and is designed to match Android/Backend implementations.
        if let predicate = try? JSONValueMatcher.EqualsPredicate(from: decoder) { return predicate }
        if let predicate = try? JSONValueMatcher.NumberRangePredicate(from: decoder) { return predicate }
        if let predicate = try? JSONValueMatcher.PresencePredicate(from: decoder) { return predicate }
        if let predicate = try? JSONValueMatcher.VersionPredicate(from: decoder) { return predicate }
        if let predicate = try? JSONValueMatcher.ArrayLengthPredicate(from: decoder) { return predicate }
        if let predicate = try? JSONValueMatcher.ArrayContainsPredicate(from: decoder) { return predicate }
        if let predicate = try? JSONValueMatcher.StringBeginsPredicate(from: decoder) { return predicate }
        if let predicate = try? JSONValueMatcher.StringEndsPredicate(from: decoder) { return predicate }
        if let predicate = try? JSONValueMatcher.StringContainsPredicate(from: decoder) { return predicate }
        return nil
    }

    init(predicate: any Predicate) {
        self.predicate = predicate
    }
    
    /// Creates a matcher that requires a number to be at least a minimum value.
    /// - Parameter atLeast: The minimum acceptable value.
    /// - Returns: A `JSONValueMatcher` for the specified condition.
    public class func matcherWhereNumberAtLeast(
        _ atLeast: Double
    )-> JSONValueMatcher {
        return .init(
            predicate: NumberRangePredicate(atLeast: atLeast)
        )
    }

    /// Creates a matcher that requires a number to be within a specified range.
    /// - Parameters:
    ///   - atLeast: The minimum acceptable value (inclusive).
    ///   - atMost: The maximum acceptable value (inclusive).
    /// - Returns: A `JSONValueMatcher` for the specified condition.
    public class func matcherWhereNumberAtLeast(
        _ atLeast: Double,
        atMost: Double
    ) -> JSONValueMatcher {
        return .init(
            predicate: NumberRangePredicate(
                atLeast: atLeast,
                atMost: atMost
            )
        )
    }
    
    /// Creates a matcher that requires a number to be at most a maximum value.
    /// - Parameter atMost: The maximum acceptable value.
    /// - Returns: A `JSONValueMatcher` for the specified condition.
    public class func matcherWhereNumberAtMost(
        _ atMost: Double
    ) -> JSONValueMatcher {
        return .init(
            predicate: NumberRangePredicate(
                atMost: atMost
            )
        )
    }

    /// Creates a matcher for an exact number value.
    /// - Parameter number: The exact number to match.
    /// - Returns: A `JSONValueMatcher` for the specified condition.
    public class func matcherWhereNumberEquals(
        to number: Double
    ) -> JSONValueMatcher {
        return .init(
            predicate: EqualsPredicate(
                equals: .number(number)
            )
        )
    }
    
    /// Creates a matcher for an exact boolean value.
    /// - Parameter boolean: The exact boolean to match.
    /// - Returns: A `JSONValueMatcher` for the specified condition.
    public class func matcherWhereBooleanEquals(
        _ boolean: Bool
    ) -> JSONValueMatcher {
        return .init(
            predicate: EqualsPredicate(
                equals: .bool(boolean)
            )
        )
    }

    /// Creates a matcher for an exact string value.
    /// - Parameter string: The exact string to match.
    /// - Returns: A `JSONValueMatcher` for the specified condition.
    public class func matcherWhereStringEquals(
        _ string: String
    ) -> JSONValueMatcher {
        return .init(
            predicate: EqualsPredicate(
                equals: .string(string)
            )
        )
    }

    /// Creates a matcher that checks for the presence or absence of a value.
    /// - Parameter present: If `true`, the value must exist (not be null). If `false`, it must not.
    /// - Returns: A `JSONValueMatcher` for the specified condition.
    public class func matcherWhereValueIsPresent(
        _ present: Bool
    ) -> JSONValueMatcher {
        return .init(
            predicate: PresencePredicate(
                isPresent: present
            )
        )
    }

    /// Creates a matcher that checks a value against a version constraint.
    /// The value being checked is expected to be a string representing a version.
    /// - Parameter versionConstraint: The version constraint string (e.g., "1.0.0+", "[1.0, 2.0)").
    /// - Returns: A `JSONValueMatcher` for the specified condition.
    public class func matcherWithVersionConstraint(
        _ versionConstraint: String
    ) -> JSONValueMatcher? {
        return .init(
            predicate: VersionPredicate(
                versionConstraint: versionConstraint
            )
        )
    }

    /// Creates a matcher that checks if an array contains an element that matches a `JSONPredicate`.
    /// - Parameter predicate: The predicate to apply to elements in the array.
    /// - Returns: A `JSONValueMatcher` for the specified condition.
    public class func matcherWithArrayContainsPredicate(
        _ predicate: JSONPredicate
    ) -> JSONValueMatcher? {
        return .init(
            predicate: ArrayContainsPredicate(arrayContains: predicate)
        )
    }

    /// Creates a matcher that checks if an array element at a specific index matches a `JSONPredicate`.
    /// - Parameters:
    ///   - predicate: The predicate to apply to the element at the specified index.
    ///   - index: The index of the array element to check.
    /// - Returns: A `JSONValueMatcher` for the specified condition.
    public class func matcherWithArrayContainsPredicate(
        _ predicate: JSONPredicate,
        at index: Int
    ) -> JSONValueMatcher? {
        return .init(
            predicate: ArrayContainsPredicate(
                arrayContains: predicate,
                index: index
            )
        )
    }

    /// Creates a matcher from a JSON payload.
    /// - Parameter json: The JSON object to decode into a `JSONValueMatcher`.
    /// - Returns: A `JSONValueMatcher` instance.
    /// - Throws: An error if decoding fails.
    @available(*, deprecated, message: "Use Codable conformance for serialization instead.")
    public class func matcherWithJSON(_ json: Any?) throws -> JSONValueMatcher {
        return try AirshipJSON.wrap(json).decode()
    }

    public func encode(to encoder: any Encoder) throws {
        try self.predicate.encode(to: encoder)
    }

    /// The matcher's JSON payload.
    @available(*, deprecated, message: "Use Codable conformance for serialization instead.")
    public func payload() -> [String: Any] {
        return (try? AirshipJSON.wrap(self.predicate).unWrap() as? [String: Any]) ?? [:]
    }

    /// Evaluates the given value against the matcher.
    /// - Parameter value: The value to evaluate.
    /// - Returns: `true` if the value matches, otherwise `false`.
    @available(*, deprecated, message: "Use evaluate(json:ignoreCase:) instead.")
    public func evaluate(_ value: Any?) -> Bool {
        return evaluate(value, ignoreCase: false)
    }

    /// Evaluates the given value against the matcher.
    /// - Parameters:
    ///   - value: The value to evaluate.
    ///   - ignoreCase: If `true`, string comparisons will be case-insensitive.
    /// - Returns: `true` if the value matches, otherwise `false`.
    @available(*, deprecated, message: "Use evaluate(json:ignoreCase:) instead.")
    public func evaluate(_ value: Any?, ignoreCase: Bool) -> Bool {
        do {
            return try evaluate(json: .wrap(value), ignoreCase: ignoreCase)
        } catch {
            AirshipLogger.error("Failed to evaluate json: \(error)")
            return false
        }
    }

    /// Evaluates the given `AirshipJSON` value against the matcher.
    /// - Parameters:
    ///   - json: The `AirshipJSON` value to evaluate.
    ///   - ignoreCase: If `true`, string comparisons will be case-insensitive.
    /// - Returns: `true` if the value matches, otherwise `false`.
    public func evaluate(json: AirshipJSON, ignoreCase: Bool = false) -> Bool {
        self.predicate.evaluate(json: json, ignoreCase: ignoreCase)
    }

    public override func isEqual(_ other: Any?) -> Bool {
        guard let matcher = other as? JSONValueMatcher else {
            return false
        }

        if self === matcher {
            return true
        }

        return predicate.isEqual(to: matcher.predicate)
    }

    public func hash() -> Int {
        return predicate.hashValue
    }
}

extension JSONValueMatcher.Predicate {
    func isEqual(to other: any JSONValueMatcher.Predicate) -> Bool {
        // Attempt to cast the `other` existential to our own concrete type (`Self`).
        guard let otherAsSelf = other as? Self else {
            // If the types are different (e.g., comparing EqualsPredicate to
            // NumberRangePredicate), the cast will fail and they are not equal.
            return false
        }

        // If the types are the same, we can now use the concrete `==`
        // implementation provided by the Equatable conformance.
        return self == otherAsSelf
    }
}
