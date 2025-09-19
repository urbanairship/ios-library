// Copyright Airship and Contributors

import Foundation

/// A matcher for evaluating a JSON payload against a set of criteria.
///
/// `JSONMatcher` allows you to specify conditions for a JSON value, optionally at a specific key or nested path (`scope`),
/// and then evaluate if a given JSON object meets those conditions.
public final class JSONMatcher: NSObject, Sendable, Codable {

    /// The key to look for in the JSON object.
    private let key: String?

    /// The path to the value within the JSON object.
    private let scope: [String]?

    /// The matcher to apply to the found JSON value.
    private let valueMatcher: JSONValueMatcher

    /// If `true`, string comparisons will ignore case.
    private let ignoreCase: Bool?

    /// Private designated initializer.
    init(
        valueMatcher: JSONValueMatcher,
        key: String?,
        scope: [String]?,
        ignoreCase: Bool?
    ) {
        self.valueMatcher = valueMatcher
        self.key = key
        self.scope = scope
        self.ignoreCase = ignoreCase
        super.init()
    }

    /// Coding keys for backward compatibility.
    private enum CodingKeys: String, CodingKey {
        case key
        case scope
        case valueMatcher = "value"
        case ignoreCase = "ignore_case"
    }

    /// Creates a new `JSONMatcher`.
    /// - Parameter valueMatcher: The `JSONValueMatcher` to apply to the value.
    /// - Returns: A new `JSONMatcher` instance.
    public convenience init(valueMatcher: JSONValueMatcher) {
        self.init(
            valueMatcher: valueMatcher,
            key: nil,
            scope: nil,
            ignoreCase: nil
        )
    }

    /// Creates a new `JSONMatcher` with a specified scope.
    /// - Parameters:
    ///   - valueMatcher: The `JSONValueMatcher` to apply to the value.
    ///   - scope: An array of keys representing the path to the value.
    /// - Returns: A new `JSONMatcher` instance.
    public convenience init(valueMatcher: JSONValueMatcher, scope: [String]) {
        self.init(
            valueMatcher: valueMatcher,
            key: nil,
            scope: scope,
            ignoreCase: nil
        )
    }

    /// - Note: For internal use only. :nodoc:
    public convenience init(
        valueMatcher: JSONValueMatcher,
        scope: [String],
        ignoreCase: Bool
    ) {
        self.init(
            valueMatcher: valueMatcher,
            key: nil,
            scope: scope,
            ignoreCase: ignoreCase
        )
    }

    /// - Note: For internal use only. :nodoc:
    public convenience init(
        valueMatcher: JSONValueMatcher,
        ignoreCase: Bool
    ) {
        self.init(
            valueMatcher: valueMatcher,
            key: nil,
            scope: nil,
            ignoreCase: ignoreCase
        )
    }

    /// Evaluates the given `AirshipJSON` value against the matcher's criteria.
    ///
    /// This method traverses the JSON object using the `scope` and `key` to find the target value,
    /// then uses the `valueMatcher` to perform the evaluation.
    ///
    /// - Parameter json: The `AirshipJSON` object to evaluate.
    /// - Returns: `true` if the value matches the criteria; otherwise, `false`.
    public func evaluate(json: AirshipJSON) -> Bool {
        var paths: [String] = []
        if let scope = scope {
            paths.append(contentsOf: scope)
        }

        if let key = key {
            paths.append(key)
        }

        var object = json
        for path in paths {
            guard let obj = object.object else {
                object = .null
                break
            }
            object = obj[path] ?? .null
        }

        return valueMatcher.evaluate(json: object, ignoreCase: self.ignoreCase ?? false)
    }

    /// - Note: For internal use only. :nodoc:
    public override func isEqual(_ other: Any?) -> Bool {
        guard let matcher = other as? JSONMatcher else {
            return false
        }

        if self === matcher {
            return true
        }

        return isEqual(to: matcher)
    }

    /// - Note: For internal use only. :nodoc:
    public func isEqual(to matcher: JSONMatcher) -> Bool {
        guard self.valueMatcher == matcher.valueMatcher,
              self.key == matcher.key,
              self.scope == matcher.scope,
              self.ignoreCase ?? false == matcher.ignoreCase ?? false
        else {
            return false
        }

        return true
    }

    /// - Note: For internal use only. :nodoc:
    public override var hash: Int {
        var hasher = Hasher()
        hasher.combine(valueMatcher)
        hasher.combine(key)
        hasher.combine(scope)
        hasher.combine(ignoreCase)
        return hasher.finalize()
    }
}
