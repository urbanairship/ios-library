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

    func testJSONMatcherPredicate() {
        let predicate = JSONPredicate(jsonMatcher: stringMatcher)
        XCTAssertTrue(predicate.evaluate("cool"))

        XCTAssertFalse(predicate.evaluate(nil))
        XCTAssertFalse(predicate.evaluate(predicate))
        XCTAssertFalse(predicate.evaluate("falset cool"))
        XCTAssertFalse(predicate.evaluate(1))
        XCTAssertFalse(predicate.evaluate(true))
    }
    
    func testJSONMatcherPredicatePayload() throws {
        let json = ["value": ["equals": "cool"]]
        let predicate = JSONPredicate(jsonMatcher: stringMatcher)

        XCTAssertEqual(json.toNsDictionary(), predicate.payload().toNsDictionary())

        // Verify the JSONValue recreates the expected payload
        XCTAssertEqual(json.toNsDictionary(), try! JSONPredicate(json: json).payload().toNsDictionary())
    }
    
    func testNotPredicate() {
        let predicate = JSONPredicate.notPredicate(subpredicate: JSONPredicate(jsonMatcher: stringMatcher))
        XCTAssertFalse(predicate.evaluate("cool"))

        XCTAssertTrue(predicate.evaluate(nil))
        XCTAssertTrue(predicate.evaluate("no cool"))
        XCTAssertTrue(predicate.evaluate(1))
        XCTAssertTrue(predicate.evaluate(true))
    }
    
    func testNotPredicatePayload() throws {
        let json = [ "not": [ ["value": ["equals": "cool" ]] ] ]
        let prediate = JSONPredicate.notPredicate(subpredicate: JSONPredicate(jsonMatcher: stringMatcher))
        XCTAssertEqual(json.toNsDictionary(), prediate.payload().toNsDictionary())
        
        // Verify the JSONValue recreates the expected payload
        XCTAssertEqual(json.toNsDictionary(), try! JSONPredicate(json: json).payload().toNsDictionary())
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

    func testAndPredicate() {
        let fooPredicate = JSONPredicate(jsonMatcher: fooMatcher)
        let storyPredicate = JSONPredicate(jsonMatcher: storyMatcher)
        let predicate = JSONPredicate.andPredicate(subpredicates: [fooPredicate, storyPredicate])
        
        var payload = ["foo": "bar", "cool": "story"]
        XCTAssert(predicate.evaluate(payload))
        
        payload = ["foo": "bar", "cool": "story", "something": "else"]
        XCTAssert(predicate.evaluate(payload))
        
        payload = ["foo": "bar", "cool": "book"]
        XCTAssertFalse(predicate.evaluate(payload))
        
        payload = ["foo": "bar"]
        XCTAssertFalse(predicate.evaluate(payload))
        
        payload = ["cool": "story"]
        XCTAssertFalse(predicate.evaluate(payload))
        
        XCTAssertFalse(predicate.evaluate(nil))
        XCTAssertFalse(predicate.evaluate(predicate))
        XCTAssertFalse(predicate.evaluate("bar"))
        XCTAssertFalse(predicate.evaluate(1))
        XCTAssertFalse(predicate.evaluate(true))
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
        
        XCTAssertEqual(json.toNsDictionary(), predicate.payload().toNsDictionary())
        
        // Verify the JSONValue recreates the expected payload
        XCTAssertEqual(json.toNsDictionary(), try! JSONPredicate(json: json).payload().toNsDictionary())
    }
    
    func testOrPredicate() {
        let fooPredicate = JSONPredicate(jsonMatcher: fooMatcher)
        let storyPredicate = JSONPredicate(jsonMatcher: storyMatcher)
        let predicate = JSONPredicate.orPredicate(subpredicates: [fooPredicate, storyPredicate])
        
        var payload = ["foo": "bar", "cool": "story"]
        XCTAssertTrue(predicate.evaluate(payload))

        payload = ["foo": "bar", "cool": "story", "something": "else"]
        XCTAssertTrue(predicate.evaluate(payload))

        payload = ["foo": "bar"]
        XCTAssertTrue(predicate.evaluate(payload))

        payload = ["cool": "story"]
        XCTAssertTrue(predicate.evaluate(payload))

        payload = ["foo": "falset bar", "cool": "book"]
        XCTAssertFalse(predicate.evaluate(payload))

        XCTAssertFalse(predicate.evaluate(nil))
        XCTAssertFalse(predicate.evaluate(predicate))
        XCTAssertFalse(predicate.evaluate("bar"))
        XCTAssertFalse(predicate.evaluate(1))
        XCTAssertFalse(predicate.evaluate(true))
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
        
        XCTAssertEqual(json.toNsDictionary(), predicate.payload().toNsDictionary())
        
        // Verify the JSONValue recreates the expected payload
        XCTAssertEqual(json.toNsDictionary(), try! JSONPredicate(json: json).payload().toNsDictionary())
    }
    
    func testEqualArray() throws {
        let json = ["value": [ "equals": ["cool", "story"]]]
        let predicate = try! JSONPredicate(json: json)
        
        XCTAssertTrue(predicate.evaluate(["cool", "story"]))
        XCTAssertFalse(predicate.evaluate(["cool"]))
        XCTAssertFalse(predicate.evaluate(["cool", "story", "afalsether key"]))
        
        XCTAssertFalse(predicate.evaluate(nil))
        XCTAssertFalse(predicate.evaluate(predicate))
        XCTAssertFalse(predicate.evaluate("bar"))
        XCTAssertFalse(predicate.evaluate(1))
        XCTAssertFalse(predicate.evaluate(true))
    }
    
    func testEqualObject() throws {
        let json = ["value": [ "equals": [ "cool": "story" ] ]]
        let predicate = try! JSONPredicate(json: json)
        
        XCTAssertTrue(predicate.evaluate(["cool": "story"]))
        XCTAssertFalse(predicate.evaluate(["cool": "story?"]))
        XCTAssertFalse(predicate.evaluate(["cool": "story", "afalsether_key": "afalsether_value"]))

        XCTAssertFalse(predicate.evaluate(nil))
        XCTAssertFalse(predicate.evaluate(predicate))
        XCTAssertFalse(predicate.evaluate("bar"))
        XCTAssertFalse(predicate.evaluate(1))
        XCTAssertFalse(predicate.evaluate(true))
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
