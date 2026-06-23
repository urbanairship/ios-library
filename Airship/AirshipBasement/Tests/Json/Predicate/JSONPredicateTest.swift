/* Copyright Airship and Contributors */

import Testing
import Foundation
@testable import AirshipBasement

struct JSONPredicateTest {

    let fooMatcher: JSONMatcher
    let storyMatcher: JSONMatcher
    let stringMatcher: JSONMatcher

    init() {
        fooMatcher = JSONMatcher(valueMatcher: JSONValueMatcher.matcherWhereStringEquals("bar"), scope: ["foo"])
        storyMatcher = JSONMatcher(valueMatcher: JSONValueMatcher.matcherWhereStringEquals("story"), scope: ["cool"])
        stringMatcher = JSONMatcher(valueMatcher: JSONValueMatcher.matcherWhereStringEquals("cool"))
    }

    @Test
    func codable() throws {

        let json: String = """
        {
            "or":[
                 {
                     "value":{
                         "equals":"bar"
                     },
                     "scope":[
                         "foo"
                     ]
                 },
                 {
                     "value":{
                         "equals":"story"
                     },
                     "scope":[
                         "cool"
                     ]
                 }
            ]
        }
        """

        let decoded: JSONPredicate = try JSONDecoder().decode(
            JSONPredicate.self,
            from: json.data(using: .utf8)!
        )

        let expected: JSONPredicate = .orPredicate(
            subpredicates: [
                JSONPredicate(
                    jsonMatcher: JSONMatcher(
                        valueMatcher: JSONValueMatcher.matcherWhereStringEquals("bar"),
                        scope: ["foo"]
                    )
                ),
                JSONPredicate(
                    jsonMatcher: JSONMatcher(
                        valueMatcher: JSONValueMatcher.matcherWhereStringEquals("story"),
                        scope: ["cool"]
                    )
                )
            ]
        )

        #expect(decoded == expected)

        let encoded = String(data: try JSONEncoder().encode(decoded), encoding: .utf8)
        #expect(try AirshipJSON.from(json: json) == AirshipJSON.from(json: encoded))
    }

    @Test
    func jsonMatcherPredicate() throws {
        let predicate = JSONPredicate(jsonMatcher: stringMatcher)
        #expect(predicate.evaluate(json: try AirshipJSON.wrap("cool")))

        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(nil)))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(predicate)))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap("falset cool")))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(1)))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(true)))
    }

    @Test
    func jsonMatcherPredicatePayload() throws {
        let json = ["value": ["equals": "cool"]]
        let predicate = JSONPredicate(jsonMatcher: stringMatcher)

        #expect(try AirshipJSON.wrap(json) == AirshipJSON.wrap(predicate))

        // Verify the JSONValue recreates the expected payload
        #expect(predicate == (try AirshipJSON.wrap(json).decode()))
    }

    @Test
    func notPredicate() throws {
        let predicate = JSONPredicate.notPredicate(subpredicate: JSONPredicate(jsonMatcher: stringMatcher))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap("cool")))

        #expect(predicate.evaluate(json: try AirshipJSON.wrap(nil)))
        #expect(predicate.evaluate(json: try AirshipJSON.wrap("no cool")))
        #expect(predicate.evaluate(json: try AirshipJSON.wrap(1)))
        #expect(predicate.evaluate(json: try AirshipJSON.wrap(true)))
    }

    @Test
    func notPredicatePayload() throws {
        let json = [ "not": [ ["value": ["equals": "cool" ]] ] ]
        let predicate = JSONPredicate.notPredicate(subpredicate: JSONPredicate(jsonMatcher: stringMatcher))
        #expect(try AirshipJSON.wrap(json) == AirshipJSON.wrap(predicate))

        // Verify the JSONValue recreates the expected payload
        #expect(predicate == (try AirshipJSON.wrap(json).decode()))
    }

    @Test
    func jsonPredicateNotNoArray() throws {
        let json: String = """
        {
            "not": {
                 "value":{
                     "equals":"bar"
                 },
                 "scope":[
                     "foo"
                 ]
           }
        }
        """

        let decoded: JSONPredicate = try JSONDecoder().decode(
            JSONPredicate.self,
            from: json.data(using: .utf8)!
        )

        let expected: JSONPredicate = .notPredicate(
            subpredicate: JSONPredicate(
                jsonMatcher: JSONMatcher(
                    valueMatcher: JSONValueMatcher.matcherWhereStringEquals("bar"),
                    scope: ["foo"]
                )
            )
        )

        #expect(decoded == expected)
    }

    @Test
    func jsonPredicateNotWithArray() throws {
        let json: String = """
        {
            "not": [{
                 "value":{
                     "equals":"bar"
                 },
                 "scope":[
                     "foo"
                 ]
           }]
        }
        """

        let decoded: JSONPredicate = try JSONDecoder().decode(
            JSONPredicate.self,
            from: json.data(using: .utf8)!
        )

        let expected: JSONPredicate = .notPredicate(
            subpredicate: JSONPredicate(
                jsonMatcher: JSONMatcher(
                    valueMatcher: JSONValueMatcher.matcherWhereStringEquals("bar"),
                    scope: ["foo"]
                )
            )
        )

        #expect(decoded == expected)
    }

    @Test
    func jsonPredicateNotWithArrayMultipleElements() throws {
        let json: String = """
        {
            "not":[
                 {
                     "value":{
                         "equals":"bar"
                     },
                     "scope":[
                         "foo"
                     ]
                 },
                 {
                     "value":{
                         "equals":"bar"
                     },
                     "scope":[
                         "foo"
                     ]
                 }
            ]
        }
        """

        do {
            _  = try JSONDecoder().decode(
                JSONPredicate.self,
                from: json.data(using: .utf8)!
            )
            Issue.record("shoudl throw")
        } catch {

        }
    }

    @Test
    func jsonPredicateArrayLength() throws {
        // This JSON is flawed as you cant have an array of matchers for value. However it shows
        // order of matcher parsing and its the same test on web, so we are using it.
        let json: String = """
        {
          "value": {
            "array_contains": {
                "value": {
                  "equals": 2,
                },
            },
            "array_length": {
                "value": {
                  "equals": 1,
                },
            },
          },
        }
        """

        let predicate: JSONPredicate = try JSONDecoder().decode(
            JSONPredicate.self,
            from: json.data(using: .utf8)!
        )

        #expect(predicate.evaluate(json: try AirshipJSON.wrap([2])))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap([0, 1, 2])))
    }

    @Test
    func andPredicate() throws {
        let fooPredicate = JSONPredicate(jsonMatcher: fooMatcher)
        let storyPredicate = JSONPredicate(jsonMatcher: storyMatcher)
        let predicate = JSONPredicate.andPredicate(subpredicates: [fooPredicate, storyPredicate])

        var payload: [String: String] = ["foo": "bar", "cool": "story"]
        #expect(predicate.evaluate(json: try AirshipJSON.wrap(payload)))

        payload = ["foo": "bar", "cool": "story", "something": "else"]
        #expect(predicate.evaluate(json: try AirshipJSON.wrap(payload)))

        payload = ["foo": "bar", "cool": "book"]
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(payload)))

        payload = ["foo": "bar"]
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(payload)))

        payload = ["cool": "story"]
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(payload)))

        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(nil)))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(predicate)))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap("bar")))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(1)))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(true)))
    }

    @Test
    func andPredicatePayload() throws {
        let json = [
            "and": [
                ["value": ["equals": "bar"], "scope": ["foo"]],
                ["value": ["equals": "story"], "scope": ["cool"]],
            ]
        ]

        let fooPredicate = JSONPredicate(jsonMatcher: fooMatcher)
        let storyPredicate = JSONPredicate(jsonMatcher: storyMatcher)
        let predicate = JSONPredicate.andPredicate(subpredicates: [fooPredicate, storyPredicate])

        #expect(try AirshipJSON.wrap(json) == AirshipJSON.wrap(predicate))

        // Verify the JSONValue recreates the expected payload
        #expect(predicate == (try AirshipJSON.wrap(json).decode()))

    }

    @Test
    func orPredicate() throws {
        let fooPredicate = JSONPredicate(jsonMatcher: fooMatcher)
        let storyPredicate = JSONPredicate(jsonMatcher: storyMatcher)
        let predicate = JSONPredicate.orPredicate(subpredicates: [fooPredicate, storyPredicate])

        var payload: [String: String] = ["foo": "bar", "cool": "story"]
        #expect(predicate.evaluate(json: try AirshipJSON.wrap(payload)))

        payload = ["foo": "bar", "cool": "story", "something": "else"]
        #expect(predicate.evaluate(json: try AirshipJSON.wrap(payload)))

        payload = ["foo": "bar"]
        #expect(predicate.evaluate(json: try AirshipJSON.wrap(payload)))

        payload = ["cool": "story"]
        #expect(predicate.evaluate(json: try AirshipJSON.wrap(payload)))

        payload = ["foo": "falset bar", "cool": "book"]
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(payload)))

        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(nil)))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(predicate)))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap("bar")))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(1)))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(true)))
    }

    @Test
    func orPredicatePayload() throws {
        let json = [
            "or": [
                ["value": ["equals": "bar"], "scope": ["foo"]],
                ["value": ["equals": "story"], "scope": ["cool"]],
            ]
        ]

        let fooPredicate = JSONPredicate(jsonMatcher: fooMatcher)
        let storyPredicate = JSONPredicate(jsonMatcher: storyMatcher)
        let predicate = JSONPredicate.orPredicate(subpredicates: [fooPredicate, storyPredicate])

        #expect(try AirshipJSON.wrap(json) == AirshipJSON.wrap(predicate))

        // Verify the JSONValue recreates the expected payload
        #expect(predicate == (try AirshipJSON.wrap(json).decode()))
    }

    @Test
    func equalArray() throws {
        let json = ["value": [ "equals": ["cool", "story"]]]
        let predicate = try JSONPredicate(json: json)

        #expect(predicate.evaluate(json: try AirshipJSON.wrap(["cool", "story"])))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(["cool"])))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(["cool", "story", "afalsether key"])))

        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(nil)))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(predicate)))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap("bar")))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(1)))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(true)))
    }

    @Test
    func equalObject() throws {
        let json = ["value": [ "equals": [ "cool": "story" ] ]]
        let predicate = try JSONPredicate(json: json)

        #expect(predicate.evaluate(json: try AirshipJSON.wrap(["cool": "story"])))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(["cool": "story?"])))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(["cool": "story", "afalsether_key": "afalsether_value"])))

        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(nil)))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(predicate)))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap("bar")))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(1)))
        #expect(!predicate.evaluate(json: try AirshipJSON.wrap(true)))
    }

    @Test
    func invalidPayload() throws {
        // Invalid type
        var json: [String: Any] = [
            "what": [
                ["value": [ "equals": "bar" ], "key": "foo"],
                ["value": [ "equals": "story" ], "key": "cool"]
            ]
        ]

        #expect(throws: (any Error).self) { try JSONPredicate(json: json) }

        // Invalid key value
        json = [
            "or": [
                "not_cool",
                ["value": ["equals": "story"], "key": "cool" ]
            ]
        ]
        #expect(throws: (any Error).self) { try JSONPredicate(json: json) }

        // Invalid object
        #expect(throws: (any Error).self) { try JSONPredicate(json: "not cool") }
    }
}
