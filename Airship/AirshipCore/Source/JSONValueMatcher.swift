// Copyright Airship and Contributors

/**
 * Defines a JSON value matcher.
 */
@objc(UAJSONValueMatcher)
public class JSONValueMatcher : NSObject {
    private static let atMostKey = "at_most"
    private static let atLeastKey = "at_least"
    private static let equalsKey = "equals"
    private static let isPresentKey = "is_present"
    private static let versionConstraintKey = "version_matches"
    private static let alternateVersionConstraintKey = "version"
    private static let arrayContainsKey = "array_contains"
    private static let arrayIndexKey = "index"
    private static let errorDomainKey = "com.urbanairship.json_value_matcher"
    
    private var atLeast: NSNumber?
    private var atMost: NSNumber?
    private var isPresent: NSNumber?
    private var equals: Any?
    private var versionConstraint: String?
    private var versionMatcher: VersionMatcher?
    private var arrayPredicate: JSONPredicate?
    private var arrayIndex: NSNumber?

    /**
     * The matcher's JSON payload.
     */
    @objc
    public func payload() -> [String : Any] {
        var payload: [String : Any] = [:]

        payload[JSONValueMatcher.equalsKey] = equals
        payload[JSONValueMatcher.atLeastKey] = atLeast
        payload[JSONValueMatcher.atMostKey] = atMost
        payload[JSONValueMatcher.isPresentKey] = isPresent
        payload[JSONValueMatcher.versionConstraintKey] = versionConstraint
        payload[JSONValueMatcher.arrayIndexKey] = arrayIndex
        payload[JSONValueMatcher.arrayContainsKey] = arrayPredicate?.payload()

        return payload
    }

    /**
     * Evaluates the object with the matcher.
     *
     * - Parameters:
     *   - value: The object to evaluate.
     * - Returns: true  if the matcher matches the object, otherwise false.
     */
    @objc(evaluateObject:)
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
    @objc(evaluateObject:ignoreCase:)
    public func evaluate(_ value: Any?, ignoreCase: Bool) -> Bool {
        if let isPresent = isPresent {
            return isPresent.boolValue == (value != nil)
        }

        if let equals = equals {
            if !self.value(equals, isEqualToValue: value, ignoreCase: ignoreCase) {
                return false
            }
        }
        
        let numberValue = ((value is NSNumber) ? value : nil) as? NSNumber
        let stringValue = ((value is NSString) ? value : nil) as? String
        
        if let atLeast = atLeast {
            guard let nValue = numberValue, atLeast.compare(nValue) != .orderedDescending else {
                return false
            }
        }
        
        if let atMost = atMost {
            guard let nValue = numberValue, atMost.compare(nValue) != .orderedAscending else {
                return false
            }
        }
        
        if let versionMatcher = versionMatcher {
            if !(stringValue != nil && versionMatcher.evaluate(value)) {
                return false
            }
        }

        if let arrayPredicate = arrayPredicate {
            guard let array = value as? [AnyHashable] else {
                return false
            }

            if let arrayIndex = arrayIndex {
                let index = arrayIndex.intValue
                if index < 0 || index >= array.count {
                    return false
                }
                return arrayPredicate.evaluate(array[index])
            } else {
                for element in array {
                    if arrayPredicate.evaluate(element) {
                        return true
                    }
                }
                return false
            }
        }

        return true
    }

    /// - Note: For internal use only. :nodoc:
    @objc(value:isEqualToValue:ignoreCase:)
    public func value(_ valueOne: Any?, isEqualToValue valueTwo: Any?, ignoreCase: Bool) -> Bool {
        
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
            if ignoreCase {
                return valueOne.caseInsensitiveCompare(valueTwo) == .orderedSame
            } else {
                return valueOne == valueTwo
            }
        }
        
        if let valueOne = valueOne as? [AnyHashable] {
            guard let valueTwo = valueTwo as? [AnyHashable] else {
                return false
            }
            
            if valueOne.count != valueTwo.count {
                return false
            }
            
            for i in 0..<valueOne.count {
                if !value(valueOne[i], isEqualToValue: valueTwo[i], ignoreCase: ignoreCase) {
                    return false
                }
            }
            return true
        }
        
        if let valueOne = valueOne as? [AnyHashable : Any] {
            guard let valueTwo = valueTwo as? [AnyHashable : Any] else {
                return false
            }
            
            if valueOne.count != valueTwo.count {
                return false
            }
            
            for key in valueOne.keys {
                if !value(valueOne[key], isEqualToValue: valueTwo[key], ignoreCase: ignoreCase) {
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
    @objc(matcherWhereNumberAtLeast:)
    public class func matcherWhereNumberAtLeast(atLeast number: NSNumber) -> JSONValueMatcher {
        let matcher = JSONValueMatcher()
        matcher.atLeast = number
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
    @objc(matcherWhereNumberAtLeast:atMost:)
    public class func matcherWhereNumberAtLeast(atLeast lowerNumber: NSNumber, atMost higherNumber: NSNumber) -> JSONValueMatcher {
        let matcher = JSONValueMatcher()
        matcher.atLeast = lowerNumber
        matcher.atMost = higherNumber
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
    @objc(matcherWhereNumberAtMost:)
    public class func matcherWhereNumberAtMost(atMost number: NSNumber) -> JSONValueMatcher {
        let matcher = JSONValueMatcher()
        matcher.atMost = number
        return matcher
    }

    /**
     * Factory method to create a matcher for an exact number.
     *
     * - Parameters:
     *   - number: The expected number value.
     * - Returns: A value matcher.
     */
    @objc(matcherWhereNumberEquals:)
    public class func matcherWhereNumberEquals(_ number: NSNumber) -> JSONValueMatcher {
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
    @objc(matcherWhereBooleanEquals:)
    public class func matcherWhereBooleanEquals(_ boolean: Bool) -> JSONValueMatcher {
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
    @objc(matcherWhereStringEquals:)
    public class func matcherWhereStringEquals(_ string: String) -> JSONValueMatcher {
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
    @objc(matcherWhereValueIsPresent:)
    public class func matcherWhereValueIsPresent(_ present: Bool) -> JSONValueMatcher {
        let matcher = JSONValueMatcher()
        matcher.isPresent = NSNumber(value: present)
        return matcher
    }

    /**
     * Factory method to create a matcher for a version constraint.
     *
     * - Parameters:
     *   - versionConstraint The version constraint to be matched against.
     * - Returns: A value matcher.
     */
    @objc(matcherWithVersionConstraint:)
    public class func matcherWithVersionConstraint(_ versionConstraint: String) -> JSONValueMatcher? {
        guard let versionMatcher = VersionMatcher.matcher(versionConstraint: versionConstraint) else {
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
    @objc(matcherWithArrayContainsPredicate:)
    public class func matcherWithArrayContainsPredicate(_ predicate: JSONPredicate) -> JSONValueMatcher? {
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
    @objc(matcherWithArrayContainsPredicate:atIndex:)
    public class func matcherWithArrayContainsPredicate(_ predicate: JSONPredicate, at index: Int) -> JSONValueMatcher? {
        let matcher = JSONValueMatcher()
        matcher.arrayPredicate = predicate
        matcher.arrayIndex = NSNumber(value: index)
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
    @objc(matcherWithJSON:error:)
    public class func matcherWithJSON(_ json: Any?) throws -> JSONValueMatcher {
        guard let parsedJson = json as? [String : Any] else {
            AirshipLogger.error("Attempted to deserialize invalid object: \(String(describing: json))")
            throw AirshipErrors.error("Attempted to deserialize invalid object: \(String(describing: json))")
        }

        if self.isEqualMatcherExpression(parsedJson) {
            let matcher = JSONValueMatcher()
            matcher.equals = parsedJson[JSONValueMatcher.equalsKey]
            return matcher
        }

        if self.isNumericMatcherExpression(parsedJson) {
            let matcher = JSONValueMatcher()
            matcher.atMost = parsedJson[JSONValueMatcher.atMostKey] as? NSNumber
            matcher.atLeast = parsedJson[JSONValueMatcher.atLeastKey] as? NSNumber
            return matcher
        }

        if self.isPresentExpression(parsedJson) {
            return self.matcherWhereValueIsPresent((parsedJson[JSONValueMatcher.isPresentKey] as? NSNumber)?.boolValue ?? false)
        }

        if self.isArrayMatcherExpression(parsedJson) {
            let matcher = JSONValueMatcher()
            matcher.arrayPredicate = try JSONPredicate.fromJson(json: parsedJson[JSONValueMatcher.arrayContainsKey])
            matcher.arrayIndex = parsedJson[JSONValueMatcher.arrayIndexKey] as? NSNumber
            return matcher
        }

        if let constraint = parsedJson[JSONValueMatcher.versionConstraintKey] as? NSString {
            if let matcher = self.matcherWithVersionConstraint(constraint as String) {
                return matcher
            }
        }

        if let constraint = parsedJson[JSONValueMatcher.alternateVersionConstraintKey] as? NSString {
            if let matcher = self.matcherWithVersionConstraint(constraint as String) {
                return matcher
            }
        }

        /// Invalid
        AirshipLogger.error("Invalid value matcher: \(String(describing: json))")
        throw AirshipErrors.error("Invalid value matcher: \(String(describing: json))")
    }

    @objc(isEqualMatcherExpression:)
    class func isEqualMatcherExpression(_ expression: [AnyHashable : Any]) -> Bool {
        /// "equals": *
        if (expression.count) != 1 {
            return false
        }

        return expression[JSONValueMatcher.equalsKey] != nil
    }

    @objc(isNumericMatcherExpression:)
    class func isNumericMatcherExpression(_ expression: [AnyHashable : Any]) -> Bool {
        /// "at_least": number | "at_most": number | "at_least": number, "at_most": number
        guard (expression.count) > 0 && (expression.count) < 3 else {
            return false
        }

        if (expression.count) == 1 {
            return (expression[JSONValueMatcher.atLeastKey] is NSNumber) || (expression[JSONValueMatcher.atMostKey] is NSNumber)
        }

        if (expression.count) == 2 {
            return (expression[JSONValueMatcher.atLeastKey] is NSNumber) && (expression[JSONValueMatcher.atMostKey] is NSNumber)
        }
        
        return false
    }

    @objc(isPresentExpression:)
    class func isPresentExpression(_ expression: [AnyHashable : Any]) -> Bool {
        guard (expression.count) == 1 else {
            return false
        }

        let subexp = expression[JSONValueMatcher.isPresentKey]

        /// Note: it's not possible to reflect a pure boolean value here so this will accept non-binary numbers as well
        return subexp is NSNumber
    }

    @objc(isArrayMatcherExpression:)
    class func isArrayMatcherExpression(_ expression: [AnyHashable : Any]) -> Bool {
        guard (expression.count) > 0 && (expression.count) < 3 else {
            return false
        }

        if (expression.count) == 1 {
            return expression[JSONValueMatcher.arrayContainsKey] is [AnyHashable : Any]
        }

        return (expression[JSONValueMatcher.arrayContainsKey] is [AnyHashable : Any]) && (expression[JSONValueMatcher.arrayIndexKey] is NSNumber)
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

    @objc(isEqualToJSONValueMatcher:)
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
            if matcher?.versionConstraint == nil || versionConstraint != matcher?.versionConstraint {
                return false
            }
        }
        if let arrayPredicate = arrayPredicate {
            if arrayPredicate != matcher?.arrayPredicate && !arrayPredicate.isEqual(matcher?.arrayPredicate) {
                return false
            }
        }
        if let arrayIndex = arrayIndex {
            if arrayIndex != matcher?.arrayIndex && !arrayIndex.isEqual(matcher?.arrayIndex) {
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
        result = 31 * result + (atLeast?.hash ?? 0)
        result = 31 * result + (atMost?.hash ?? 0)
        result = 31 * result + (isPresent?.hash ?? 0)
        result = 31 * result + (versionConstraint?.hash ?? 0)
        result = 31 * result + (arrayPredicate?.hash ?? 0)
        result = 31 * result + (arrayIndex?.hash ?? 0)
        return result
    }
}
