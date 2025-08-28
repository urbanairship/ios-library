// Copyright Airship and Contributors



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
                let versionMatcher = try AirshipIvyVersionMatcher(versionConstraint: versionConstraint)
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
            return if ignoreCase {
                isEqualIgnoreCase(valueOne: equals, valueTwo: json)
            } else {
                equals == json
            }
        }


        func isEqualIgnoreCase(valueOne: AirshipJSON, valueTwo: AirshipJSON) -> Bool {
            if let string = valueOne.string, let otherString = valueTwo.string {
                return string.normalizedIgnoreCaseComparison() == otherString.normalizedIgnoreCaseComparison()
            }

            if let array = valueOne.array, let otherArray = valueTwo.array {
                guard array.count == otherArray.count else {
                    return false
                }

                for (index, element) in array.enumerated() {
                    guard isEqualIgnoreCase(valueOne: element, valueTwo: otherArray[index]) else {
                        return false
                    }
                }

                return true
            }

            if let object = valueOne.object, let otherObject = valueTwo.object {
                guard object.count == otherObject.count else {
                    return false
                }

                for (key, value) in object {
                    guard
                        let otherValue = otherObject[key],
                        isEqualIgnoreCase(valueOne: value, valueTwo: otherValue)
                    else {
                        return false
                    }
                }

                return true
            }

            // Remaining types - bool, number, mismatch types
            return valueOne == valueTwo
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

    struct StringBeginsPredicate: Predicate {
        var stringBegins: String

        func evaluate(json: AirshipJSON, ignoreCase: Bool) -> Bool {
            guard let string = json.string else { return false }

            return if ignoreCase {
                string.normalizedIgnoreCaseComparison().hasPrefix(
                    stringBegins.normalizedIgnoreCaseComparison()
                )
            } else {
                string.hasPrefix(stringBegins)
            }
        }

        enum CodingKeys: String, CodingKey {
            case stringBegins = "string_begins"
        }
    }

    struct StringEndsPredicate: Predicate {
        var stringEnds: String

        func evaluate(json: AirshipJSON, ignoreCase: Bool) -> Bool {
            guard let string = json.string else { return false }
            return if ignoreCase {
                string.normalizedIgnoreCaseComparison().hasSuffix(
                    stringEnds.normalizedIgnoreCaseComparison()
                )
            } else {
                string.hasSuffix(stringEnds)
            }
        }

        enum CodingKeys: String, CodingKey {
            case stringEnds = "string_ends"
        }
    }

    struct StringContainsPredicate: Predicate {
        var stringContains: String

        func evaluate(json: AirshipJSON, ignoreCase: Bool) -> Bool {
            guard let string = json.string else { return false }
            return if ignoreCase {
                string.normalizedIgnoreCaseComparison().contains(
                    stringContains.normalizedIgnoreCaseComparison()
                )
            } else {
                string.contains(stringContains)
            }
        }

        enum CodingKeys: String, CodingKey {
            case stringContains = "string_contains"
        }
    }
}

fileprivate extension String {
    /// Returns a normalized representation of the string for case- and diacritic-insensitive comparisons.
    ///
    /// This method "folds" the string into a simplified form by removing case distinctions (e.g., "a" vs. "A")
    /// and diacritical marks (e.g., "é" vs. "e"). The resulting string is suitable for reliable,
    /// locale-agnostic comparisons where variations in case or accents should be ignored.
    ///
    /// - Returns: A normalized string, ready for comparison.
    func normalizedIgnoreCaseComparison() -> String {
        return self.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: nil
        )
    }
}
