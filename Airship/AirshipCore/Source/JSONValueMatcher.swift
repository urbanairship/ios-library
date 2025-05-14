// Copyright Airship and Contributors

import Foundation

/// Defines a JSON value matcher.
public final class JSONValueMatcher: NSObject, @unchecked Sendable, Codable {
    private static let errorDomainKey = "com.urbanairship.json_value_matcher"

    private var atLeast: Double?
    private var atMost: Double?
    private var isPresent: Bool?
    private var equals: Any?
    private var versionConstraint: String?
    private var versionMatcher: VersionMatcher?
    private var arrayPredicate: JSONPredicate?
    private var arrayIndex: Int?
    private var arrayLength: JSONPredicate?
    
    private enum CodingKeys: String, CodingKey {
        case atLeast = "at_least"
        case atMost = "at_most"
        case isPresent = "is_present"
        case equals
        case versionConstraintOld = "version"
        case versionConstraint = "version_matches"
        case versionMatcher
        case arrayPredicate = "array_contains"
        case arrayIndex = "index"
        case arrayLength = "array_length"
    }
    
    override public init() {
        super.init()
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.atLeast = try container.decodeIfPresent(Double.self, forKey: .atLeast)
        self.atMost = try container.decodeIfPresent(Double.self, forKey: .atMost)

        self.isPresent = try container.decodeIfPresent(Bool.self, forKey: .isPresent)
        self.arrayPredicate = try container.decodeIfPresent(JSONPredicate.self, forKey: .arrayPredicate)
        self.arrayIndex = try container.decodeIfPresent(Int.self, forKey: .arrayIndex)
        self.arrayLength = try container.decodeIfPresent(JSONPredicate.self, forKey: .arrayLength)
        self.equals = try container.decodeIfPresent(AirshipJSON.self, forKey: .equals)?.unWrap()
        
        if container.contains(.versionConstraintOld) {
            self.versionConstraint = try container.decode(String.self, forKey: .versionConstraintOld)
        } else {
            self.versionConstraint = try container.decodeIfPresent(String.self, forKey: .versionConstraint)
        }
        
        if container.contains(.versionMatcher) {
            self.versionMatcher = try container.decode(VersionMatcher.self, forKey: .versionMatcher)
        } else if let versionConstraint {
            self.versionMatcher = VersionMatcher.matcher(versionConstraint: versionConstraint)
        } else {
            self.versionMatcher = nil
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(atLeast, forKey: .atLeast)
        try container.encodeIfPresent(atMost, forKey: .atMost)
        try container.encodeIfPresent(isPresent, forKey: .isPresent)
        try container.encodeIfPresent(versionConstraint, forKey: .versionConstraint)
        try container.encodeIfPresent(versionMatcher, forKey: .versionMatcher)
        try container.encodeIfPresent(arrayPredicate, forKey: .arrayPredicate)
        try container.encodeIfPresent(arrayIndex, forKey: .arrayIndex)
        try container.encodeIfPresent(arrayLength, forKey: .arrayLength)
        
        if let equals {
            try container.encodeIfPresent(try? AirshipJSON.wrap(equals), forKey: .equals)
        }
    }

    /**
     * The matcher's JSON payload.
     */
    public func payload() -> [String: Any] {
        var payload: [String: Any] = [:]

        payload[CodingKeys.equals.rawValue] = equals
        payload[CodingKeys.atLeast.rawValue] = atLeast
        payload[CodingKeys.atMost.rawValue] = atMost
        payload[CodingKeys.isPresent.rawValue] = isPresent
        payload[CodingKeys.versionConstraint.rawValue] = versionConstraint
        payload[CodingKeys.arrayIndex.rawValue] = arrayIndex
        payload[CodingKeys.arrayPredicate.rawValue] = arrayPredicate?.payload()
        payload[CodingKeys.arrayLength.rawValue] = arrayLength?.payload()

        return payload
    }

    /**
     * Evaluates the object with the matcher.
     *
     * - Parameters:
     *   - value: The object to evaluate.
     * - Returns: true  if the matcher matches the object, otherwise false.
     */
    public func evaluate(_ value: Any?) -> Bool {
        return evaluate(value, ignoreCase: false)
    }

    /**
     * Evaluates the object with the matcher.
     *
     * - Parameters:
     *   - value: The object to evaluate.
     *   - ignoreCase: YES to ignore case when checking String values, NO to check case.
     *  Strings contained in arrays and dictionaries also follow this rule.
     * - Returns: true if the matcher matches the object, otherwise false.
     */
    public func evaluate(_ value: Any?, ignoreCase: Bool) -> Bool {
        if let isPresent = isPresent {
            return isPresent == (value != nil)
        }

        if let equals = equals {
            if !self.value(
                equals,
                isEqualToValue: value,
                ignoreCase: ignoreCase
            ) {
                return false
            }
        }
        
        let numberValue: Double? = if value is any Numeric {
            switch value {
            case let intValue as Int: Double(intValue)
            case let doubleValue as Double: doubleValue
            default: nil
            }
        } else {
            nil
        }
        
        let stringValue = ((value is NSString) ? value : nil) as? String

        if let atLeast = atLeast {
            guard let nValue = numberValue, nValue >= atLeast  else {
                return false
            }
        }

        if let atMost = atMost {
            guard let nValue = numberValue, nValue <= atMost else {
                return false
            }
        }

        if let versionMatcher = versionMatcher {
            if !(stringValue != nil && versionMatcher.evaluate(value)) {
                return false
            }
        }

        if let arrayLength {
            guard let array = value as? [AnyHashable] else {
                return false
            }

            return arrayLength.evaluate(array.count)
        }


        if let arrayPredicate = arrayPredicate {
            guard let array = value as? [AnyHashable] else {
                return false
            }

            guard let arrayIndex = arrayIndex else {
                for element in array {
                    if arrayPredicate.evaluate(element) {
                        return true
                    }
                }
                return false
            }
            
            if arrayIndex < 0 || arrayIndex >= array.count {
                return false
            }
            return arrayPredicate.evaluate(array[arrayIndex])
        }

        return true
    }

    /// - Note: For internal use only. :nodoc:
    public func value(
        _ valueOne: Any?,
        isEqualToValue valueTwo: Any?,
        ignoreCase: Bool
    ) -> Bool {

        if let valueOne = valueOne as? NSNumber {
            guard let valueTwo = valueTwo as? NSNumber else {
                return false
            }
            return valueOne == valueTwo
        }

        if let valueOne = valueOne as? String {
            guard let valueTwo = valueTwo as? String else {
                return false
            }
            guard ignoreCase else {
                return valueOne == valueTwo
            }
            return valueOne.caseInsensitiveCompare(valueTwo) == .orderedSame
        }

        if let valueOne = valueOne as? [AnyHashable] {
            guard let valueTwo = valueTwo as? [AnyHashable] else {
                return false
            }

            if valueOne.count != valueTwo.count {
                return false
            }

            for i in 0..<valueOne.count {
                if !value(
                    valueOne[i],
                    isEqualToValue: valueTwo[i],
                    ignoreCase: ignoreCase
                ) {
                    return false
                }
            }
            return true
        }

        if let valueOne = valueOne as? [AnyHashable: Any] {
            guard let valueTwo = valueTwo as? [AnyHashable: Any] else {
                return false
            }

            if valueOne.count != valueTwo.count {
                return false
            }

            for key in valueOne.keys {
                if !value(
                    valueOne[key],
                    isEqualToValue: valueTwo[key],
                    ignoreCase: ignoreCase
                ) {
                    return false
                }
            }
            return true
        }

        return false
    }

    /**
     * Factory method to create a matcher for a number that is
     * at least the specified number.
     *
     * - Parameters:
     *   -  number: The lower bound for the number.
     * - Returns: A value matcher.
     */
    public class func matcherWhereNumberAtLeast(atLeast number: NSNumber)
        -> JSONValueMatcher
    {
        let matcher = JSONValueMatcher()
        matcher.atLeast = number.doubleValue
        return matcher
    }

    /**
     * Factory method to create a matcher for a number between
     * the lowerNumber and higherNumber.
     *
     * - Parameters:
     *   - lowerNumber: The lower bound for the number.
     *   - higherNumber: The upper bound for the number.
     * - Returns: A value matcher.
     */
    public class func matcherWhereNumberAtLeast(
        atLeast lowerNumber: NSNumber,
        atMost higherNumber: NSNumber
    ) -> JSONValueMatcher {
        let matcher = JSONValueMatcher()
        matcher.atLeast = lowerNumber.doubleValue
        matcher.atMost = higherNumber.doubleValue
        return matcher
    }

    /**
     * Factory method to create a matcher for a number that is
     * at most the specified number.
     *
     * - Parameters:
     *   - number: The upper bound for the number.
     * - Returns: A value matcher.
     */
    public class func matcherWhereNumberAtMost(atMost number: NSNumber)
        -> JSONValueMatcher
    {
        let matcher = JSONValueMatcher()
        matcher.atMost = number.doubleValue
        return matcher
    }

    /**
     * Factory method to create a matcher for an exact number.
     *
     * - Parameters:
     *   - number: The expected number value.
     * - Returns: A value matcher.
     */
    public class func matcherWhereNumberEquals(_ number: NSNumber)
        -> JSONValueMatcher
    {
        let matcher = JSONValueMatcher()
        matcher.equals = number
        return matcher
    }

    /**
     * Factory method to create a matcher for an exact boolean.
     *
     * - Parameters:
     *   - boolean: The expected boolean value.
     * - Returns: A value matcher.
     */
    public class func matcherWhereBooleanEquals(_ boolean: Bool)
        -> JSONValueMatcher
    {
        let matcher = JSONValueMatcher()
        matcher.equals = NSNumber(value: boolean)
        return matcher
    }

    /**
     * Factory method to create a matcher for an exact string.
     *
     * - Parameters:
     *   - string: The expected string value.
     * - Returns: A value matcher.
     */
    public class func matcherWhereStringEquals(_ string: String)
        -> JSONValueMatcher
    {
        let matcher = JSONValueMatcher()
        matcher.equals = string
        return matcher
    }

    /**
     * Factory method to create a matcher for the presence of a value.
     *
     * - Parameters:
     *   - present: true if the value must be present, otherwise false.
     * - Returns: A value matcher.
     */
    public class func matcherWhereValueIsPresent(_ present: Bool)
        -> JSONValueMatcher
    {
        let matcher = JSONValueMatcher()
        matcher.isPresent = present
        return matcher
    }

    /**
     * Factory method to create a matcher for a version constraint.
     *
     * - Parameters:
     *   - versionConstraint The version constraint to be matched against.
     * - Returns: A value matcher.
     */
    public class func matcherWithVersionConstraint(_ versionConstraint: String)
        -> JSONValueMatcher?
    {
        guard
            let versionMatcher = VersionMatcher.matcher(
                versionConstraint: versionConstraint
            )
        else {
            return nil
        }

        let valueMatcher = JSONValueMatcher()
        valueMatcher.versionConstraint = versionConstraint
        valueMatcher.versionMatcher = versionMatcher
        return valueMatcher
    }

    /**
     * Factory method to create a matcher for an array value.
     *
     * - Parameters:
     *   - predicate A predicate to be used to evaluate each value in the array for a match.
     * - Returns:  A value matcher.
     */
    public class func matcherWithArrayContainsPredicate(
        _ predicate: JSONPredicate
    ) -> JSONValueMatcher? {
        let matcher = JSONValueMatcher()
        matcher.arrayPredicate = predicate
        return matcher
    }

    /**
     * Factory method to create a matcher for a value in an array.
     *
     * - Parameters:
     *   - predicate A predicate to be used to evaluate the value at the index.
     *   -  index The array index.
     * - Returns: A value matcher.
     */
    public class func matcherWithArrayContainsPredicate(
        _ predicate: JSONPredicate,
        at index: Int
    ) -> JSONValueMatcher? {
        let matcher = JSONValueMatcher()
        matcher.arrayPredicate = predicate
        matcher.arrayIndex = index
        return matcher
    }

    /**
     * Factory method to create a matcher from a JSON payload.
     *
     * - Parameters:
     *   - json The JSON payload.
     *   - error An NSError pointer for storing errors, if applicable.
     * - Returns: A value matcher, or `nil` if the JSON is invalid.
     */
    public class func matcherWithJSON(_ json: Any?) throws -> JSONValueMatcher {
        guard let parsedJson = json as? [String: Any] else {
            AirshipLogger.error(
                "Attempted to deserialize invalid object: \(String(describing: json))"
            )
            throw AirshipErrors.error(
                "Attempted to deserialize invalid object: \(String(describing: json))"
            )
        }

        if self.isEqualMatcherExpression(parsedJson) {
            let matcher = JSONValueMatcher()
            matcher.equals = parsedJson[CodingKeys.equals.rawValue]
            return matcher
        }

        if self.isNumericMatcherExpression(parsedJson) {
            let matcher = JSONValueMatcher()
            matcher.atMost = (parsedJson[CodingKeys.atMost.rawValue] as? NSNumber)?.doubleValue
            matcher.atLeast = (parsedJson[CodingKeys.atLeast.rawValue] as? NSNumber)?.doubleValue
            return matcher
        }

        if self.isPresentExpression(parsedJson) {
            return self.matcherWhereValueIsPresent(
                (parsedJson[CodingKeys.isPresent.rawValue] as? NSNumber)?
                    .boolValue
                    ?? false
            )
        }

        if let arrayLength = parsedJson[CodingKeys.arrayLength.rawValue] {
            let matcher = JSONValueMatcher()
            matcher.arrayLength = try JSONPredicate.fromJson(
                json: arrayLength
            )
            return matcher
        }

        if self.isArrayMatcherExpression(parsedJson) {
            let matcher = JSONValueMatcher()
            matcher.arrayPredicate = try JSONPredicate.fromJson(
                json: parsedJson[CodingKeys.arrayPredicate.rawValue]
            )
            matcher.arrayIndex = (parsedJson[CodingKeys.arrayIndex.rawValue] as? NSNumber)?.intValue
            return matcher
        }

        if let constraint = parsedJson[CodingKeys.versionConstraint.rawValue]
            as? NSString
        {
            if let matcher = self.matcherWithVersionConstraint(
                constraint as String
            ) {
                return matcher
            }
        }

        if let constraint =
            parsedJson[CodingKeys.versionConstraintOld.rawValue]
            as? NSString
        {
            if let matcher = self.matcherWithVersionConstraint(
                constraint as String
            ) {
                return matcher
            }
        }

        /// Invalid
        AirshipLogger.error(
            "Invalid value matcher: \(String(describing: json))"
        )
        throw AirshipErrors.error(
            "Invalid value matcher: \(String(describing: json))"
        )
    }

    class func isEqualMatcherExpression(_ expression: [AnyHashable: Any])
        -> Bool
    {
        /// "equals": *
        if (expression.count) != 1 {
            return false
        }

        return expression[CodingKeys.equals.rawValue] != nil
    }

    class func isNumericMatcherExpression(_ expression: [AnyHashable: Any])
        -> Bool
    {
        /// "at_least": number | "at_most": number | "at_least": number, "at_most": number
        guard (expression.count) > 0 && (expression.count) < 3 else {
            return false
        }

        if (expression.count) == 1 {
            return (expression[CodingKeys.atLeast.rawValue] is NSNumber)
                || (expression[CodingKeys.atMost.rawValue] is NSNumber)
        }

        if (expression.count) == 2 {
            return (expression[CodingKeys.atLeast.rawValue] is NSNumber)
                && (expression[CodingKeys.atMost.rawValue] is NSNumber)
        }

        return false
    }

    class func isPresentExpression(_ expression: [AnyHashable: Any]) -> Bool {
        guard (expression.count) == 1 else {
            return false
        }

        let subexp = expression[CodingKeys.isPresent.rawValue]

        /// Note: it's not possible to reflect a pure boolean value here so this will accept non-binary numbers as well
        return subexp is NSNumber
    }

    class func isArrayMatcherExpression(_ expression: [AnyHashable: Any])
        -> Bool
    {
        guard (expression.count) > 0 && (expression.count) < 3 else {
            return false
        }

        if (expression.count) == 1 {
            return expression[CodingKeys.arrayPredicate.rawValue]
                is [AnyHashable: Any]
        }

        return (expression[CodingKeys.arrayPredicate.rawValue] is [AnyHashable: Any])
                && (expression[CodingKeys.arrayIndex.rawValue] is NSNumber)
    }

    /// - Note: For internal use only. :nodoc:
    public override func isEqual(_ other: Any?) -> Bool {
        guard let matcher = other as? JSONValueMatcher? else {
            return false
        }

        if self === matcher {
            return true
        }

        return isEqual(to: matcher)
    }

    func isEqual(to matcher: JSONValueMatcher?) -> Bool {
        if let equals = equals {
            if matcher?.equals == nil || !compareAny(equals, matcher?.equals) {
                return false
            }
        }
        if let atLeast = atLeast {
            if matcher?.atLeast == nil || !(atLeast == matcher?.atLeast) {
                return false
            }
        }
        if let atMost = atMost {
            if matcher?.atMost == nil || !(atMost == matcher?.atMost) {
                return false
            }
        }
        if let isPresent = isPresent {
            if matcher?.isPresent == nil || !(isPresent == matcher?.isPresent) {
                return false
            }
        }
        if let versionConstraint = versionConstraint {
            if matcher?.versionConstraint == nil
                || versionConstraint != matcher?.versionConstraint
            {
                return false
            }
        }
        if let arrayPredicate = arrayPredicate {
            if arrayPredicate != matcher?.arrayPredicate
                && !arrayPredicate.isEqual(matcher?.arrayPredicate)
            {
                return false
            }
        }
        if let arrayIndex = arrayIndex {
            if arrayIndex != matcher?.arrayIndex {
                return false
            }
        }
        return true
    }

    private func compareAny(_ a: Any?, _ b: Any?) -> Bool {
        if let dict = a as? NSDictionary {
            return dict.isEqual(b)
        } else if let array = a as? NSArray {
            return array.isEqual(b)
        } else if let number = a as? NSNumber {
            return number.isEqual(b)
        } else if let string = a as? String {
            return string.isEqual(b)
        } else {
            return false
        }
    }

    func hash() -> Int {
        var result = 1
        var equalsHashValue = 0

        if let equals = equals as? NSObject {
            equalsHashValue = equals.hash
        } else if let equals = equals as? NSNumber {
            equalsHashValue = equals.hash
        } else if let equals = equals as? String {
            equalsHashValue = equals.hash
        }
        
        result = 31 * result + equalsHashValue
        result = 31 * result + (atLeast?.hashValue ?? 0)
        result = 31 * result + (atMost?.hashValue ?? 0)
        result = 31 * result + (isPresent?.hashValue ?? 0)
        result = 31 * result + (versionConstraint?.hashValue ?? 0)
        result = 31 * result + (arrayPredicate?.hashValue ?? 0)
        result = 31 * result + (arrayIndex?.hashValue ?? 0)
        return result
    }
}
