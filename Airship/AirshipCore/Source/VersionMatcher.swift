// Copyright Airship and Contributors

enum UAVersionMatcherConstraintType {
    case unknown
    case exactVersion
    case subVersion
    case versionRange
}

enum UAVersionMatcherRangeBoundary : Int {
    case inclusive
    case exclusive
    case infinite
}

/**
 * Version matcher.
 */
@objc(UAVersionMatcher)
public class VersionMatcher : NSObject {
    
    private static let EXACT_VERSION_PATTERN = "^([0-9]+)(\\.[0-9]+)?(\\.[0-9]+)?$"
    private static let START_INCLUSIVE = "["
    private static let START_EXCLUSIVE = "]"
    private static let START_INFINITE = "("
    private static let END_INCLUSIVE = "]"
    private static let END_EXCLUSIVE = "["
    private static let END_INFINITE = ")"
    private static let RANGE_SEPARATOR = ","
    private static let ESCAPE_CHAR = "\\"
    private static let START_TOKENS = ESCAPE_CHAR + START_INCLUSIVE + ESCAPE_CHAR + START_EXCLUSIVE + ESCAPE_CHAR + START_INFINITE
    private static let END_TOKENS = ESCAPE_CHAR + END_INCLUSIVE + ESCAPE_CHAR + END_EXCLUSIVE + ESCAPE_CHAR + END_INFINITE
    private static let START_END_TOKENS = START_TOKENS + END_TOKENS
    private static let START_PATTERN = "([" + START_TOKENS + "])"
    private static let END_PATTERN = "([" + END_TOKENS + "])"
    private static let SEPARATOR_PATTERN = "(" + RANGE_SEPARATOR + ")"
    private static let VERSION_PATTERN = "([^" + START_END_TOKENS + RANGE_SEPARATOR + "]*)"
    private static let VERSION_RANGE_PATTERN = START_PATTERN + VERSION_PATTERN + SEPARATOR_PATTERN + VERSION_PATTERN + END_PATTERN
    
    /**
     * The original versionConstraint used to create this matcher
     */
    public let versionConstraint: String
    
    private let constraintType: UAVersionMatcherConstraintType
    private let parsedConstraint: [AnyHashable : Any]

    /// NOTE: For internal use only. :nodoc:
    @objc
    public init?(versionConstraint: String) {
        let strippedVersionConstraint = VersionMatcher.removeWhitespace(versionConstraint)
        self.versionConstraint = versionConstraint

        if let parsedConstraint = VersionMatcher.parseExactVersionConstraint(strippedVersionConstraint) {
            self.constraintType = .exactVersion
            self.parsedConstraint = parsedConstraint
        } else if let parsedConstraint = VersionMatcher.parseSubVersionConstraint(strippedVersionConstraint) {
            self.constraintType = .subVersion
            self.parsedConstraint = parsedConstraint
        } else if let parsedConstraint = VersionMatcher.parseVersionRangeConstraint(strippedVersionConstraint) {
            self.constraintType = .versionRange
            self.parsedConstraint = parsedConstraint
        } else {
            return nil
        }
    }

    /**
     * Create a matcher for the supplied version contraint
     *
     * - Parameters:
     *   - versionConstraint: constraint that matches one of our supported patterns
     * - Returns: matcher or nil if versionConstraint does not match any of the expected patterns
     */
    @objc(matcherWithVersionConstraint:)
    public class func matcher(versionConstraint: String) -> VersionMatcher? {
        return VersionMatcher(versionConstraint: versionConstraint)
    }

    // MARK: -
    // MARK: Evaluate version against constraint
    /**
     * Evaluates the object with the matcher.
     *
     * - Parameters:
     *   - value: The object to evaluate.
     * - Returns: true if the matcher matches the object, otherwise false.
     */
    @objc(evaluateObject:)
    public func evaluate(_ value: Any?) -> Bool {
        guard let value = value as? String else {
            return false
        }
        let checkVersion = Self.removeWhitespace(value)

        switch constraintType {
            case .exactVersion:
                return versionMatchesExactVersion(checkVersion)
            case .subVersion:
                return versionMatchesSubVersion(checkVersion)
            case .versionRange:
                return versionMatchesRange(checkVersion)
            default:
                return false
        }
    }

    /**
     * Check if versionConstraint matches the "exact version" pattern
     *
     * - Parameters:
     *   - versionConstraint: constraint string
     * - Returns: true if versionConstraint matches the "exact version" pattern
     */
    @objc
    public class func isExactVersion(_ versionConstraint: String) -> Bool {
        return self.parseExactVersionConstraint(versionConstraint) != nil
    }

    @objc
    class func parseExactVersionConstraint(_ versionConstraint: String) -> [AnyHashable : Any]? {
        var versionConstraint = versionConstraint
        versionConstraint = Self.removeWhitespace(versionConstraint)

        guard let matches = try? Self.getMatchesForPattern(EXACT_VERSION_PATTERN, on: versionConstraint), matches.count == 1 else {
            return nil
        }

        return [
            "exactVersion": versionConstraint
        ]
    }

    @objc
    func versionMatchesExactVersion(_ checkVersion: String) -> Bool {
        if constraintType != .exactVersion {
            return false
        }

        return checkVersion.isEqual(parsedConstraint["exactVersion"])
    }

    // MARK: -
    // MARK: SubVersion Matcher
    static let SUB_VERSION_PATTERN = "^(.*)\\+$"

    /**
     * Check if versionConstraint matches the "sub version" pattern
     *
     * - Parameters:
     *   - versionConstraint: constraint string
     * - Returns: true if versionConstraint matches the "sub version" pattern
     */
    @objc
    public class func isSubVersion(_ versionConstraint: String) -> Bool {
        return self.parseSubVersionConstraint(versionConstraint) != nil
    }
    
    private class func parseSubVersionConstraint(_ versionConstraint: String) -> [AnyHashable : Any]? {
        var versionConstraint = versionConstraint
        versionConstraint = self.removeWhitespace(versionConstraint)

        guard let matches = try? self.getMatchesForPattern(SUB_VERSION_PATTERN, on: versionConstraint), matches.count == 1 else {
            return nil
        }

        let range = matches[0].range(at: 1)
        let versionNumberPart: String = (versionConstraint as NSString).substring(with: range)

        let parsedConstraint = [
            "subVersion": versionNumberPart
        ]

        /// allows "1.2+"
        if self.isExactVersion(versionNumberPart) {
            return parsedConstraint
        }

        /// allows "1.2.+"
        if self.isExactVersion((versionNumberPart) + "0") {
            return parsedConstraint
        }

        return nil
    }

    private func versionMatchesSubVersion(_ checkVersion: String) -> Bool {
        if constraintType != .subVersion {
            return false
        }

        guard let subVersion = parsedConstraint["subVersion"] as? String else {
            return false
        }
        
        let index: String.Index = subVersion.index(subVersion.startIndex, offsetBy: min(subVersion.count, checkVersion.count))
        let cv = checkVersion[..<index]

        /// if the version being matched is longer than the constraint, only compare its prefix
        if (checkVersion.count > subVersion.count) {
            return subVersion == cv
        } else {
            return subVersion == checkVersion
        }
    }

    /**
     * Check if versionConstraint matches the "version range" pattern
     *
     * - Parameters:
     *   - versionConstraint: constraint string
     * - Returns: true if versionConstraint matches the "version range" pattern
     */
    @objc
    public class func isVersionRange(_ versionConstraint: String) -> Bool {
        return self.parseVersionRangeConstraint(versionConstraint) != nil
    }

    private class func parseVersionRangeConstraint(_ versionConstraint: String) -> [AnyHashable : Any]? {
        var versionConstraint = versionConstraint
        enum UAVersionRangeMatcherTokenPosition : Int {
            case UAVersionRangeMatcherTokenStartBoundary = 0
            case UAVersionRangeMatcherTokenStartVersion = 1
            case UAVersionRangeMatcherTokenSeparator = 2
            case UAVersionRangeMatcherTokenEndVersion = 3
            case UAVersionRangeMatcherTokenEndBoundary = 4
        }


        versionConstraint = self.removeWhitespace(versionConstraint)

        guard let matches = try? Self.getMatchesForPattern(VERSION_RANGE_PATTERN, on: versionConstraint), matches.count == 1 else {
            return nil
        }

        /// extract tokens from version constraint
        let match = matches[0]
        let numberOfTokens = (match.numberOfRanges) - 1
        var tokens: [String] = []
        for index in 1...numberOfTokens {
            let range = match.range(at: index)
            let aToken: String = (versionConstraint as NSString).substring(with: range)
            tokens.append(aToken)
        }

        if numberOfTokens != UAVersionRangeMatcherTokenPosition.UAVersionRangeMatcherTokenEndBoundary.rawValue + 1 {
            return nil
        }

        /// first token
        var startBoundary: UAVersionMatcherRangeBoundary
        if tokens[UAVersionRangeMatcherTokenPosition.UAVersionRangeMatcherTokenStartBoundary.rawValue] == START_INCLUSIVE {
            startBoundary = .inclusive
        } else if tokens[UAVersionRangeMatcherTokenPosition.UAVersionRangeMatcherTokenStartBoundary.rawValue] == START_EXCLUSIVE {
            startBoundary = .exclusive
        } else if tokens[UAVersionRangeMatcherTokenPosition.UAVersionRangeMatcherTokenStartBoundary.rawValue] == START_INFINITE {
            startBoundary = .infinite
        } else {
            return nil
        }

        let startOfRange = ((tokens[UAVersionRangeMatcherTokenPosition.UAVersionRangeMatcherTokenStartVersion.rawValue].count) == 0) ? nil : tokens[1]

        /// infinite boundary, and only infinite boundary, can have empty associated value
        if startBoundary == .infinite {
            if startOfRange != nil {
                return nil
            }
        } else {
            if startOfRange == nil {
                return nil
            }
        }

        /// separator
        if tokens[UAVersionRangeMatcherTokenPosition.UAVersionRangeMatcherTokenSeparator.rawValue] != RANGE_SEPARATOR {
            return nil
        }

        // ending version value
        var endBoundary: UAVersionMatcherRangeBoundary
        if tokens[UAVersionRangeMatcherTokenPosition.UAVersionRangeMatcherTokenEndBoundary.rawValue] == END_INCLUSIVE {
            endBoundary = .inclusive
        } else if tokens[UAVersionRangeMatcherTokenPosition.UAVersionRangeMatcherTokenEndBoundary.rawValue] == END_EXCLUSIVE {
            endBoundary = .exclusive
        } else if tokens[UAVersionRangeMatcherTokenPosition.UAVersionRangeMatcherTokenEndBoundary.rawValue] == END_INFINITE {
            endBoundary = .infinite
        } else {
            return nil
        }

        let endOfRange = ((tokens[UAVersionRangeMatcherTokenPosition.UAVersionRangeMatcherTokenEndVersion.rawValue].count) == 0) ? nil : tokens[UAVersionRangeMatcherTokenPosition.UAVersionRangeMatcherTokenEndVersion.rawValue]

        /// infinite boundary, and only infinite boundary, can have empty associated value
        if endBoundary == .infinite {
            if endOfRange != nil {
                return nil
            }
        } else {
            if endOfRange == nil {
                return nil
            }
        }

        /// can't have infinite boundary at both start and end
        if (startBoundary == .infinite) && (endBoundary == .infinite) {
            return nil
        }

        let parsedConstraint: [AnyHashable : Any] = [
            "startBoundary": NSNumber(value: startBoundary.rawValue),
            "endBoundary": NSNumber(value: endBoundary.rawValue),
            "startOfRange": startOfRange ?? NSNull(),
            "endOfRange": endOfRange ?? NSNull()
        ]

        return parsedConstraint
    }

    @objc
    func versionMatchesRange(_ checkVersion: String) -> Bool {
        if constraintType != .versionRange {
            return false
        }
        
        guard let startRangeBoundary = (parsedConstraint["startBoundary"] as? NSNumber)?.intValue else {
            return false
        }
        let startBoundary = UAVersionMatcherRangeBoundary(rawValue: startRangeBoundary)
        
        if startBoundary != .infinite {
            if (parsedConstraint["startOfRange"] is NSNull) {
                return false
            }
            guard let startOfRange = parsedConstraint["startOfRange"] as? String else {
                return false
            }
            let result = Utils.compareVersion(startOfRange, toVersion: checkVersion)
            switch startBoundary {
                case .inclusive:
                    if result != .orderedAscending && result != .orderedSame {
                        return false
                    }
                case .exclusive:
                    if result != .orderedAscending {
                        return false
                    }
                default:
                    return false
            }
        }

        guard let endRangeBoundary = parsedConstraint["endBoundary"] as? Int else {
            return false
        }
        
        let endBoundary = UAVersionMatcherRangeBoundary(rawValue: endRangeBoundary)
        
        if endBoundary != .infinite {
            if (parsedConstraint["endOfRange"] is NSNull) {
                return false
            }
            guard let endOfRange = parsedConstraint["endOfRange"] as? String else {
                return false
            }
            let result = Utils.compareVersion(checkVersion, toVersion: endOfRange)
            switch endBoundary {
                case .inclusive:
                    if result != .orderedAscending && result != .orderedSame {
                        return false
                    }
                case .exclusive:
                    if result != .orderedAscending {
                        return false
                    }
                default:
                    return false
            }
        }

        return true
    }

    private class func getMatchesForPattern(_ pattern: String?, on string: String?) throws -> [NSTextCheckingResult] {
        var regex: NSRegularExpression? = nil
        do {
            regex = try NSRegularExpression(
                pattern: pattern ?? "",
                options: .caseInsensitive)
        } catch {
            AirshipLogger.error("Error creating regular expression - \(pattern ?? "")")
            throw AirshipErrors.error("Error creating regular expression - \(pattern ?? "")")
        }

        guard let matches = regex?.matches(in: string ?? "", options: [], range: NSRange(location: 0, length: string?.count ?? 0)) else {
            AirshipLogger.error("Error creating regular expression - \(pattern ?? "")")
            throw AirshipErrors.error("Error creating regular expression - \(pattern ?? "")")
        }
        return matches
    }

    @objc
    class func removeWhitespace(_ sourceString: String) -> String {
        let destString = (sourceString as NSString).replacingOccurrences(of: "\\s", with: "", options: .regularExpression, range: NSRange(location: 0, length: sourceString.count))
        return destString
    }

    
    /// - Note: For internal use only. :nodoc:
    @objc(isEqual:)
    public override func isEqual(_ other: Any?) -> Bool {
        guard let other = other as? VersionMatcher else {
            return false
        }
        
        return isEqual(to: other)
    }

    @objc(isEqualToVersionMatcher:)
    func isEqual(to matcher: VersionMatcher?) -> Bool {
        return matcher?.versionConstraint == self.versionConstraint
    }

    func hash() -> Int {
        var result = 1
        result = 31 * result + versionConstraint.hash
        return result
    }
}
