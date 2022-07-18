/* Copyright Airship and Contributors */

/**
 * Predicate for JSON payloads.
 */
@objc(UAJSONPredicate)
public class JSONPredicate : NSObject {
    private static let andTypeKey = "and"
    private static let orTypeKey = "or"
    private static let notTypeKey = "not"
    private static let errorDomainKey = "com.urbanairship.json_predicate"
    
    private var type: String?
    private var subpredicates: [JSONPredicate]?
    private var jsonMatcher: JSONMatcher?

    @objc
    required init(
        type: String?,
        jsonMatcher: JSONMatcher?,
        subpredicates: [JSONPredicate]?
    ) {

        super.init()
        self.type = type
        self.jsonMatcher = jsonMatcher
        self.subpredicates = subpredicates
    }
    
    
    /**
     * Factory method to create a predicate from a JSON payload.
     *
     * - Parameters:
     *   - json The JSON payload.
     * - Returns: A predicate or `nil` if the JSON is invalid.
     */
    @objc(initWithJSON:error:)
    public convenience init(json: Any?) throws {
        guard let parsedJson = json as? [String : Any] else {
            AirshipLogger.error("Attempted to deserialize invalid object: \(json ?? "")")
            throw AirshipErrors.parseError("Attempted to deserialize invalid object: \(json ?? "")")
        }

        var type: String?
        if parsedJson[JSONPredicate.andTypeKey] != nil {
            type = JSONPredicate.andTypeKey
        } else if parsedJson[JSONPredicate.orTypeKey] != nil {
            type = JSONPredicate.orTypeKey
        } else if parsedJson[JSONPredicate.notTypeKey] != nil {
            type = JSONPredicate.notTypeKey
        }
        
        if type != nil && parsedJson.count != 1 {
            AirshipLogger.error("Invalid JSON: \(String(describing: json))")
            throw AirshipErrors.parseError("Invalid JSON: \(String(describing: json))")
        }

        if let type = type {
            var subpredicates: [JSONPredicate] = []
            guard let typeInfo = parsedJson[type] as? [Any] else {
                AirshipLogger.error("Attempted to deserialize invalid object")
                throw AirshipErrors.parseError("Attempted to deserialize invalid object")
            }

            if ((type == JSONPredicate.notTypeKey) && typeInfo.count != 1) || typeInfo.count == 0 {
                AirshipLogger.error("A `not` predicate must contain a single sub predicate or matcher.")
                throw AirshipErrors.error("A `not` predicate must contain a single sub predicate or matcher.")
            }

            for subpredicateInfo in typeInfo {
                guard let predicate = try? JSONPredicate(json: subpredicateInfo) else {
                    AirshipLogger.error("Invalid JSON: \(String(describing: json))")
                    throw AirshipErrors.parseError("Invalid JSON: \(String(describing: json))")
                }

                subpredicates.append(predicate)
            }

            self.init(type: type, jsonMatcher: nil, subpredicates: subpredicates)
        } else if let jsonMatcher = try? JSONMatcher(json: json) {
            self.init(type: nil, jsonMatcher: jsonMatcher, subpredicates: nil)
        } else {
            AirshipLogger.error("Invalid JSON: \(String(describing: json))")
            throw AirshipErrors.parseError("Invalid JSON: \(String(describing: json))")
        }
    }

    /**
     * Gets the predicate's JSON payload.
     *
     * - Returns: The predicate's JSON payload.
     */
    @objc
    public func payload() -> [String : Any] {
        if let type = type {
            var subpredicatePayloads: [Any] = []
            for predicate in subpredicates ?? [] {
                subpredicatePayloads.append(predicate.payload())
            }

            return [
                type: subpredicatePayloads
            ]
        }

        return jsonMatcher?.payload() ?? [:]
    }

    /**
     * Evaluates the object with the predicate.
     *
     * - Parameters:
     *   -  object: The object to evaluate.
     * - Returns: true if the predicate matches the object, otherwise false.
     */
    @objc(evaluateObject:)
    public func evaluate(_ object: Any?) -> Bool {
        // And
        if type == JSONPredicate.andTypeKey {
            for predicate in subpredicates ?? [] {
                if !predicate.evaluate(object) {
                    return false
                }
            }
            return true
        }

        // Or
        if type == JSONPredicate.orTypeKey {
            for predicate in subpredicates ?? [] {
                if predicate.evaluate(object) {
                    return true
                }
            }
            return false
        }

        // Not
        if type == JSONPredicate.notTypeKey {
            /// The factory methods prevent NOT from ever having more than 1 predicate
            return !(subpredicates?.first?.evaluate(object) ?? false)
        }

        /// Matcher
        return jsonMatcher?.evaluate(object) ?? false
    }

    /**
     * Creates a JSON predicate from a JSONMatcher.
     *
     * - Parameters:
     *   -  matcher: A JSON matcher.
     * - Returns: A JSON predicate.
     */
    @objc(initWithJSONMatcher:)
    public convenience init(jsonMatcher matcher: JSONMatcher?) {
        self.init(type: nil, jsonMatcher: matcher, subpredicates: nil)
    }

    /**
     * Factory method to create a JSON predicate formed by AND-ing an array of predicates.
     *
     * - Parameters:
     *   - subpredicates: An array of predicates.
     * - Returns: A JSON predicate.
     */
    @objc(andPredicateWithSubpredicates:)
    public class func andPredicate(subpredicates: [JSONPredicate]?) -> JSONPredicate {
        return JSONPredicate(type: JSONPredicate.andTypeKey, jsonMatcher: nil, subpredicates: subpredicates)
    }

    /**
     * Factory method to create a JSON predicate formed by OR-ing an array of predicates.
     *
     * - Parameters:
     *   - subpredicates: An array of predicates.
     * - Returns: A JSON predicate.
     */
    @objc(orPredicateWithSubpredicates:)
    public class func orPredicate(subpredicates: [JSONPredicate]?) -> JSONPredicate {
        return JSONPredicate(type: JSONPredicate.orTypeKey, jsonMatcher: nil, subpredicates: subpredicates)

    }

    /**
     * Factory method to create a JSON predicate by NOT-ing a predicate.
     *
     * - Parameters:
     *   -  subpredicate: A predicate.
     * - Returns:A JSON predicate.
     */
    @objc(notPredicateWithSubpredicate:)
    public class func notPredicate(subpredicate: JSONPredicate) -> JSONPredicate {
        return JSONPredicate(type: JSONPredicate.notTypeKey, jsonMatcher: nil, subpredicates: [subpredicate].compactMap { $0 })
    }

    /**
     * Factory method to create a predicate from a JSON payload.
     *
     * - Parameters:
     *   - json: The JSON payload.
     * - Returns: A predicate or `nil` if the JSON is invalid.
     */
    @objc(predicateWithJSON:error:)
    class func fromJson(json: Any?) throws -> JSONPredicate {
        return try JSONPredicate(json: json)
    }

    public override var description: String {
        return String(format: "JSONPredicate{predicate=\(payload())}")
    }
}
