// Copyright Airship and Contributors

import Foundation

extension JSONValueMatcher {

    struct VersionPredicate: Predicate {
        let versionConstraint: String

        init(versionConstraint: String) {
            self.versionConstraint = versionConstraint
        }
        
        func evaluate(json: AirshipJSON, ignoreCase: Bool) -> Bool {
            guard let version = json.string else {
                return false
            }

            do {
                let versionMatcher = try IvyVersionMatcher(versionConstraint: versionConstraint)
                return versionMatcher.evaluate(version: version)
            } catch {
                AirshipLogger.error("Invalid constraint \(versionConstraint)")
            }

            return false
        }

        enum CodingKeys: String, CodingKey {
            case versionMatches = "version_matches"
            case deprecatedVersionMatches = "version"
        }

        func encode(to encoder: any Encoder) throws {
            var containter = encoder.container(keyedBy: CodingKeys.self)
            try containter.encode(versionConstraint, forKey: .versionMatches)
        }

        init(from decoder: any Decoder) throws {
            let containter = try decoder.container(keyedBy: CodingKeys.self)
            if let value = try containter.decodeIfPresent(String.self, forKey: .versionMatches) {
                self.versionConstraint = value
            } else {
                self.versionConstraint = try containter.decode(String.self, forKey: .deprecatedVersionMatches)
            }
        }
    }

    struct PresencePredicate: Predicate {
        var isPresent: Bool

        func evaluate(json: AirshipJSON, ignoreCase: Bool) -> Bool {
            return json.isNull != isPresent
        }

        enum CodingKeys: String, CodingKey {
            case isPresent = "is_present"
        }
    }

    struct EqualsPredicate: Predicate {
        var equals: AirshipJSON

        func evaluate(json: AirshipJSON, ignoreCase: Bool) -> Bool {
            if json == equals {
                return true
            }

            guard
                ignoreCase,
                let incomingString = json.string,
                let expectedString = equals.string
            else {
                return false
            }

            return expectedString.caseInsensitiveCompare(incomingString) == .orderedSame
        }
    }

    struct NumberRangePredicate: Predicate {
        var atLeast: Double?
        var atMost: Double?

        init (atLeast: Double? = nil, atMost: Double? = nil) {
            self.atLeast = atLeast
            self.atMost = atMost
        }
        
        func evaluate(json: AirshipJSON, ignoreCase: Bool) -> Bool {
            guard let number = json.number else {
                return false
            }

            if let atLeast, number < atLeast {
                return false
            }

            if let atMost, number > atMost {
                return false
            }
            
            return true
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.atLeast = try container.decodeIfPresent(Double.self, forKey: .atLeast)
            self.atMost = try container.decodeIfPresent(Double.self, forKey: .atMost)
            guard self.atLeast != nil || self.atMost != nil else {
                throw AirshipErrors.parseError("Invalid number range predicate")
            }
        }

        enum CodingKeys: String, CodingKey {
            case atLeast = "at_least"
            case atMost = "at_most"
        }
    }

    struct ArrayContainsPredicate: Predicate {
        var arrayContains: JSONPredicate
        var index: Int?

        enum CodingKeys: String, CodingKey {
            case arrayContains = "array_contains"
            case index
        }

        func evaluate(json: AirshipJSON, ignoreCase: Bool) -> Bool {
            guard let array = json.array else {
                return false
            }

            if let index {
                guard array.count > index else {
                    return false
                }

                return arrayContains.evaluate(json: array[index])
            } else {
                return array.contains { value in
                    arrayContains.evaluate(json: value)
                }
            }
        }
    }

    struct ArrayLengthPredicate: Predicate {
        var arrayLength: JSONPredicate

        func evaluate(json: AirshipJSON, ignoreCase: Bool) -> Bool {
            guard let length = json.array?.count else {
                return false
            }

            return arrayLength.evaluate(json: .number(Double(length)))
        }

        enum CodingKeys: String, CodingKey {
            case arrayLength = "array_length"
        }
    }

}
