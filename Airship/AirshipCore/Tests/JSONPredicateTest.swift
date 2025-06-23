/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class JSONPredicateTest: XCTestCase {

    var fooMatcher: JSONMatcher!
    var storyMatcher: JSONMatcher!
    var stringMatcher: JSONMatcher!

    override func setUp() {
        fooMatcher = JSONMatcher(valueMatcher: JSONValueMatcher.matcherWhereStringEquals("bar"), scope: ["foo"])
        storyMatcher = JSONMatcher(valueMatcher: JSONValueMatcher.matcherWhereStringEquals("story"), scope: ["cool"])
        stringMatcher = JSONMatcher(valueMatcher: JSONValueMatcher.matcherWhereStringEquals("cool"))
    }

    func testCodable() throws {

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

        XCTAssertEqual(decoded, expected)

        let encoded = String(data: try JSONEncoder().encode(decoded), encoding: .utf8)
        XCTAssertEqual(try AirshipJSON.from(json: json), try AirshipJSON.from(json: encoded))
    }

    func testJSONMatcherPredicate() throws {
        let predicate = JSONPredicate(jsonMatcher: stringMatcher)
        XCTAssertTrue(predicate.evaluate(json: try AirshipJSON.wrap("cool")))

        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(nil)))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(predicate)))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap("falset cool")))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(1)))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(true)))
    }

    func testJSONMatcherPredicatePayload() throws {
        let json = ["value": ["equals": "cool"]]
        let predicate = JSONPredicate(jsonMatcher: stringMatcher)

        XCTAssertEqual(try AirshipJSON.wrap(json), try AirshipJSON.wrap(predicate))

        // Verify the JSONValue recreates the expected payload
        XCTAssertEqual(predicate, try AirshipJSON.wrap(json).decode())
    }

    func testNotPredicate() throws {
        let predicate = JSONPredicate.notPredicate(subpredicate: JSONPredicate(jsonMatcher: stringMatcher))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap("cool")))

        XCTAssertTrue(predicate.evaluate(json: try AirshipJSON.wrap(nil)))
        XCTAssertTrue(predicate.evaluate(json: try AirshipJSON.wrap("no cool")))
        XCTAssertTrue(predicate.evaluate(json: try AirshipJSON.wrap(1)))
        XCTAssertTrue(predicate.evaluate(json: try AirshipJSON.wrap(true)))
    }

    func testNotPredicatePayload() throws {
        let json = [ "not": [ ["value": ["equals": "cool" ]] ] ]
        let predicate = JSONPredicate.notPredicate(subpredicate: JSONPredicate(jsonMatcher: stringMatcher))
        XCTAssertEqual(try AirshipJSON.wrap(json), try AirshipJSON.wrap(predicate))

        // Verify the JSONValue recreates the expected payload
        XCTAssertEqual(predicate, try AirshipJSON.wrap(json).decode())
    }

    func testJSONPredicateNotNoArray() throws {
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

        XCTAssertEqual(decoded, expected)
    }

    func testJSONPredicateNotWithArray() throws {
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

        XCTAssertEqual(decoded, expected)
    }

    func testJSONPredicateNotWithArrayMultipleElements() throws {
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
            XCTFail("shoudl throw")
        } catch {

        }
    }

    func testJSONPredicateArrayLength() throws {
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

        XCTAssertTrue(predicate.evaluate(json: try AirshipJSON.wrap([2])))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap([0, 1, 2])))
    }

    func testAndPredicate() throws {
        let fooPredicate = JSONPredicate(jsonMatcher: fooMatcher)
        let storyPredicate = JSONPredicate(jsonMatcher: storyMatcher)
        let predicate = JSONPredicate.andPredicate(subpredicates: [fooPredicate, storyPredicate])

        var payload: [String: String] = ["foo": "bar", "cool": "story"]
        XCTAssertTrue(predicate.evaluate(json: try AirshipJSON.wrap(payload)))

        payload = ["foo": "bar", "cool": "story", "something": "else"]
        XCTAssertTrue(predicate.evaluate(json: try AirshipJSON.wrap(payload)))

        payload = ["foo": "bar", "cool": "book"]
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(payload)))

        payload = ["foo": "bar"]
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(payload)))

        payload = ["cool": "story"]
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(payload)))

        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(nil)))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(predicate)))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap("bar")))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(1)))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(true)))
    }

    func testAndPredicatePayload() throws {
        let json = [
            "and": [
                ["value": ["equals": "bar"], "scope": ["foo"]],
                ["value": ["equals": "story"], "scope": ["cool"]],
            ]
        ]

        let fooPredicate = JSONPredicate(jsonMatcher: fooMatcher)
        let storyPredicate = JSONPredicate(jsonMatcher: storyMatcher)
        let predicate = JSONPredicate.andPredicate(subpredicates: [fooPredicate, storyPredicate])

        XCTAssertEqual(try AirshipJSON.wrap(json), try AirshipJSON.wrap(predicate))

        // Verify the JSONValue recreates the expected payload
        XCTAssertEqual(predicate, try AirshipJSON.wrap(json).decode())

    }

    func testOrPredicate() throws {
        let fooPredicate = JSONPredicate(jsonMatcher: fooMatcher)
        let storyPredicate = JSONPredicate(jsonMatcher: storyMatcher)
        let predicate = JSONPredicate.orPredicate(subpredicates: [fooPredicate, storyPredicate])

        var payload: [String: String] = ["foo": "bar", "cool": "story"]
        XCTAssertTrue(predicate.evaluate(json: try AirshipJSON.wrap(payload)))

        payload = ["foo": "bar", "cool": "story", "something": "else"]
        XCTAssertTrue(predicate.evaluate(json: try AirshipJSON.wrap(payload)))

        payload = ["foo": "bar"]
        XCTAssertTrue(predicate.evaluate(json: try AirshipJSON.wrap(payload)))

        payload = ["cool": "story"]
        XCTAssertTrue(predicate.evaluate(json: try AirshipJSON.wrap(payload)))

        payload = ["foo": "falset bar", "cool": "book"]
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(payload)))

        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(nil)))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(predicate)))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap("bar")))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(1)))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(true)))
    }

    func testOrPredicatePayload() throws {
        let json = [
            "or": [
                ["value": ["equals": "bar"], "scope": ["foo"]],
                ["value": ["equals": "story"], "scope": ["cool"]],
            ]
        ]

        let fooPredicate = JSONPredicate(jsonMatcher: fooMatcher)
        let storyPredicate = JSONPredicate(jsonMatcher: storyMatcher)
        let predicate = JSONPredicate.orPredicate(subpredicates: [fooPredicate, storyPredicate])

        XCTAssertEqual(try AirshipJSON.wrap(json), try AirshipJSON.wrap(predicate))

        // Verify the JSONValue recreates the expected payload
        XCTAssertEqual(predicate, try AirshipJSON.wrap(json).decode())
    }

    func testEqualArray() throws {
        let json = ["value": [ "equals": ["cool", "story"]]]
        let predicate = try JSONPredicate(json: json)

        XCTAssertTrue(predicate.evaluate(json: try AirshipJSON.wrap(["cool", "story"])))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(["cool"])))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(["cool", "story", "afalsether key"])))

        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(nil)))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(predicate)))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap("bar")))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(1)))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(true)))
    }

    func testEqualObject() throws {
        let json = ["value": [ "equals": [ "cool": "story" ] ]]
        let predicate = try JSONPredicate(json: json)

        XCTAssertTrue(predicate.evaluate(json: try AirshipJSON.wrap(["cool": "story"])))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(["cool": "story?"])))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(["cool": "story", "afalsether_key": "afalsether_value"])))

        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(nil)))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(predicate)))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap("bar")))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(1)))
        XCTAssertFalse(predicate.evaluate(json: try AirshipJSON.wrap(true)))
    }

    func testInvalidPayload() throws {
        // Invalid type
        var json: [String: Any] = [
            "what": [
                ["value": [ "equals": "bar" ], "key": "foo"],
                ["value": [ "equals": "story" ], "key": "cool"]
            ]
        ]

        XCTAssertThrowsError(try JSONPredicate(json: json))

        // Invalid key value
        json = [
            "or": [
                "not_cool",
                ["value": ["equals": "story"], "key": "cool" ]
            ]
        ]
        XCTAssertThrowsError(try JSONPredicate(json: json))

        // Invalid object
        XCTAssertThrowsError(try JSONPredicate(json: "not cool"))
    }
}
