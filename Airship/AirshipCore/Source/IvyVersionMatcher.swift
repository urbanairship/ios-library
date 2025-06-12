/* Copyright Airship and Contributors */

import Foundation

struct IvyVersionMatcher: Sendable {

    private static let exactVersionPattern = "^([0-9]+)(\\.([0-9]+)((\\.([0-9]+))?(.*)))?$"
    private static let subVersionPattern = "^(.*)\\+$"
    private static let startInclusive = "["
    private static let startExclusive = "]"
    private static let startInfinite = "("
    private static let endInclusive = "]"
    private static let endExclusive = "["
    private static let endInfinite = ")"
    private static let rangeSeparator = ","
    private static let escapeChar = "\\"

    private static let startTokens = escapeChar + startInclusive + escapeChar + startExclusive + escapeChar + startInfinite
    private static let endTokens = escapeChar + endInclusive + escapeChar + endExclusive + escapeChar + endInfinite
    private static let startEndTokens = startTokens + endTokens
    private static let startPattern = "([" + startTokens + "])"
    private static let endPattern = "([" + endTokens + "])"
    private static let separatorPattern = "(" + rangeSeparator + ")"
    private static let versionPattern = "([^" + startEndTokens + rangeSeparator + "]*)"
    private static let versionRangePattern = startPattern + versionPattern + separatorPattern + versionPattern + endPattern

    private enum Constraint: Sendable {
        case exactVersion(String)
        case subVersion(String)
        case versionRange(start: Boundary, end: Boundary)
    }

    private enum Boundary: Sendable {
        case inclusive(String)
        case exclusive(String)
        case infinite

        var isInfinite: Bool {
            switch self {
            case .infinite:
                return true
            default:
                return false
            }
        }
    }

    private let contraint: Constraint

    init(versionConstraint: String) throws {
        let strippedVersionConstraint = String(versionConstraint.filter { !$0.isWhitespace })

        let parsed = Self.parseSubVersionConstraint(strippedVersionConstraint) ??
        Self.parseExactVersionConstraint(strippedVersionConstraint) ??
        Self.parseVersionRangeConstraint(strippedVersionConstraint)

        guard let parsed else {
            throw AirshipErrors.error("Invalid version matcher constraint \(versionConstraint)")
        }

        self.contraint = parsed

    }

    func evaluate(version: String) -> Bool {
        let checkVersion = version.filter { !$0.isWhitespace }

        return switch self.contraint {
        case .exactVersion(let exactVersion):
            checkVersion == exactVersion
        case .subVersion(let subVersion):
            Self.evaluateSubversion(subVersion: subVersion, checkVersion: version)
        case .versionRange(let start, let end):
            Self.evaluateVersionRange(start: start, end: end, checkVersion: version)
        }
    }

    private static func parseExactVersionConstraint(
        _ versionConstraint: String
    ) -> Constraint? {
        guard
            let matches = try? Self.getMatchesForPattern(
                exactVersionPattern,
                on: versionConstraint
            ), matches.count == 1
        else {
            return nil
        }

        return .exactVersion(versionConstraint)
    }


    private static func parseSubVersionConstraint(
        _ versionConstraint: String
    ) -> Constraint? {
        guard
            let matches = try? self.getMatchesForPattern(
                subVersionPattern,
                on: versionConstraint
            ),
            matches.count == 1
        else {
            return nil
        }

        let range = matches[0].range(at: 1)
        let versionNumberPart: String = versionConstraint.airshipSubstring(with: range)

        return .subVersion(versionNumberPart)
    }


    private static func parseVersionRangeConstraint(
        _ versionConstraint: String
    ) -> Constraint? {
        guard
            let matches = try? Self.getMatchesForPattern(
                versionRangePattern,
                on: versionConstraint
            ), matches.count == 1
        else {
            return nil
        }

        /// extract tokens from version constraint
        let match = matches[0]
        let numberOfTokens = (match.numberOfRanges) - 1
        guard numberOfTokens == 5 else { return nil }

        var tokens: [String] = []
        for index in 1...numberOfTokens {
            let range = match.range(at: index)
            tokens.append(versionConstraint.airshipSubstring(with: range))
        }

        guard
            let start = parseStartRangeBoundary(tokens[0], constraint: tokens[1]),
            let end = parseEndRangeBoundary(tokens[4], constraint: tokens[3]),
            !(end.isInfinite && start.isInfinite)
        else {
            return nil
        }

        return .versionRange(start: start, end: end)

    }

    private static func evaluateSubversion(subVersion: String, checkVersion: String) -> Bool {
        let index: String.Index = subVersion.index(
            subVersion.startIndex,
            offsetBy: min(subVersion.count, checkVersion.count)
        )
        let cv = checkVersion[..<index]

        /// if the version being matched is longer than the constraint, only compare its prefix
        guard checkVersion.count > subVersion.count else {
            return subVersion == checkVersion
        }
        return subVersion == cv
    }

    private static func evaluateVersionRange(start: Boundary, end: Boundary, checkVersion: String) -> Bool {
        switch(start) {
        case .inclusive(let constraint):
            let result = AirshipUtils.compareVersion(
                constraint,
                toVersion: checkVersion,
                maxVersionParts: 3
            )
            if result != .orderedAscending && result != .orderedSame {
                return false
            }
        case .exclusive(let constraint):
            let result = AirshipUtils.compareVersion(
                constraint,
                toVersion: checkVersion,
                maxVersionParts: 3
            )
            if result != .orderedAscending {
                return false
            }
        case .infinite: break
        }

        switch(end) {
        case .inclusive(let constraint):
            let result = AirshipUtils.compareVersion(
                checkVersion,
                toVersion: constraint,
                maxVersionParts: 3
            )
            if result != .orderedAscending && result != .orderedSame {
                return false
            }
        case .exclusive(let constraint):
            let result = AirshipUtils.compareVersion(
                checkVersion,
                toVersion: constraint,
                maxVersionParts: 3
            )
            if result != .orderedAscending {
                return false
            }
        case .infinite: break
            
        }

        return true
    }

    private static func getMatchesForPattern(
        _ pattern: String,
        on string: String
    ) throws -> [NSTextCheckingResult] {
        let regex = try NSRegularExpression(
            pattern: pattern,
            options: .caseInsensitive
        )

        return regex.matches(
            in: string,
            options: [],
            range: NSRange(location: 0, length: string.count)
        )
    }

    private static func parseStartRangeBoundary(_ boundary: String, constraint: String) -> Boundary? {
        return switch(boundary) {
        case startInfinite: constraint.isEmpty ? .infinite : nil
        case startExclusive: constraint.isEmpty ? nil : .exclusive(constraint)
        case startInclusive: constraint.isEmpty ? nil : .inclusive(constraint)
        default: nil
        }
    }

    private static func parseEndRangeBoundary(_ boundary: String, constraint: String) -> Boundary? {
        return switch(boundary) {
        case endInfinite: constraint.isEmpty ? .infinite : nil
        case endExclusive: constraint.isEmpty ? nil : .exclusive(constraint)
        case endInclusive: constraint.isEmpty ? nil : .inclusive(constraint)
        default: nil
        }
    }
}

fileprivate extension String {
    // Workaround until we can drop iOS 15
    func airshipSubstring(with nsrange: NSRange) -> String {
        return (self as NSString).substring(with: nsrange)
    }
}
