/* Copyright Airship and Contributors */

import XCTest
import AirshipCore

final class JsonMatcherTest: XCTestCase {
    
    var subject = JSONValueMatcher.matcherWhereStringEquals("cool")
    
    func testMatcherOnly() {
        let matcher = JSONMatcher(valueMatcher: subject)
        XCTAssertNotNil(matcher)
        
        XCTAssertTrue(matcher.evaluate("cool"))
        
        XCTAssertFalse(matcher.evaluate(nil))
        XCTAssertFalse(matcher.evaluate(matcher))
        XCTAssertFalse(matcher.evaluate("not cool"))
        XCTAssertFalse(matcher.evaluate(1))
        XCTAssertFalse(matcher.evaluate(true))
    }
    
    func testMatcherOnlyIgnoreCase() {
        let matcher = JSONMatcher(valueMatcher: subject, ignoreCase: true)
        
        XCTAssertNotNil(matcher)
        XCTAssertTrue(matcher.evaluate("cool"))
        XCTAssertTrue(matcher.evaluate("COOL"))
        XCTAssertTrue(matcher.evaluate("CooL"))

        XCTAssertFalse(matcher.evaluate(nil))
        XCTAssertFalse(matcher.evaluate(matcher))
        XCTAssertFalse(matcher.evaluate("not cool"))
        XCTAssertFalse(matcher.evaluate("NOT COOL"))
        XCTAssertFalse(matcher.evaluate(["property": "cool"]))
        XCTAssertFalse(matcher.evaluate(1))
        XCTAssertFalse(matcher.evaluate(true))
    }
    
    func testMatcherOnlyPayload() throws {
        let json = ["value": ["equals": "cool"]]
        let matcher = JSONMatcher(valueMatcher: subject)
        
        XCTAssertEqual(json.toNsDictionary(), matcher.payload().toNsDictionary())
        XCTAssertEqual(json.toNsDictionary(), (try! JSONMatcher(json: json).payload()).toNsDictionary())
    }
    
    func testMatcherOnlyIgnoreCasePayload() throws {
        let json: [String: Any] = [
            "value": ["equals": "cool"],
            "ignore_case": true
        ]
        
        let matcher = JSONMatcher(valueMatcher: subject, ignoreCase: true)
        XCTAssertEqual(matcher.payload().toNsDictionary(), json.toNsDictionary())
        
        // Verify a matcher created from the JSON matches
        var fromJsonMatcher = try! JSONMatcher(json: json)
        XCTAssertNotNil(fromJsonMatcher)
        XCTAssertEqual(fromJsonMatcher, matcher)
        
        // Verify a matcher created from the JSON from the first matcher matches
        fromJsonMatcher = try! JSONMatcher(json: matcher.payload())
        XCTAssertNotNil(fromJsonMatcher)
        XCTAssertEqual(fromJsonMatcher, matcher)
    }
    
    func testMatcherOnlyPayloadWithUnknownKey() {
        let json: [String: Any] = [
            "value": ["equals": "cool"],
            "unknown": true
        ]
        
        let matcher = JSONMatcher(valueMatcher: subject)
        XCTAssertNotNil(matcher)
        XCTAssertNotEqual(json.toNsDictionary(), matcher.payload().toNsDictionary())
        
        // Verify a matcher created from the JSON matches
        var fromJsonMatcher = try! JSONMatcher(json: json)
        XCTAssertEqual(matcher, fromJsonMatcher)
        
        // Verify a matcher created from the JSON from the first matcher matches
        fromJsonMatcher = try! JSONMatcher(json: matcher.payload())
        XCTAssertEqual(matcher, fromJsonMatcher)
    }
    
    func testMatcherWithKey() {
        let matcher = JSONMatcher(valueMatcher: subject, scope: ["property"])
        XCTAssertTrue(matcher.evaluate(["property": "cool"]))

        XCTAssertFalse(matcher.evaluate("property"))
        XCTAssertFalse(matcher.evaluate(["property": "not cool"]))
        XCTAssertFalse(matcher.evaluate(nil))
        XCTAssertFalse(matcher.evaluate(matcher))
        XCTAssertFalse(matcher.evaluate("not cool"))
        XCTAssertFalse(matcher.evaluate(1))
        XCTAssertFalse(matcher.evaluate(true))
    }
    
    func testMatcherWithScopeIgnoreCase() {
        let matcher = JSONMatcher(valueMatcher: subject, scope: ["property"], ignoreCase: true)
        XCTAssertTrue(matcher.evaluate(["property": "cool"]))
        XCTAssertTrue(matcher.evaluate(["property": "COOL"]))
        XCTAssertTrue(matcher.evaluate(["property": "CooL"]))
        
        XCTAssertFalse(matcher.evaluate("property"))
        XCTAssertFalse(matcher.evaluate(["property": "not cool"]))
        XCTAssertFalse(matcher.evaluate(["property": "NOT COOL"]))
        XCTAssertFalse(matcher.evaluate(nil))
        XCTAssertFalse(matcher.evaluate(matcher))
        XCTAssertFalse(matcher.evaluate("not cool"))
        XCTAssertFalse(matcher.evaluate(1))
        XCTAssertFalse(matcher.evaluate(true))
    }
    
    func testScopeAsString() throws {
        // Should convert it back to an array
        let expected: [String: Any] = [
            "value": ["equals": "cool"],
            "key": "subproperty",
            "scope": ["property"]
        ]
        
        let json: [String: Any] = [
            "value": ["equals": "cool"],
            "key": "subproperty",
            "scope": ["property"]
        ]
        
        XCTAssertEqual(expected.toNsDictionary(), (try! JSONMatcher(json: json).payload()).toNsDictionary())
    }
    
    func testInvalidPayload() {
        // Invalid key value
        var json: [String: Any] = [
            "value": ["equals": "cool"],
            "key": 123,
            "scope": ["property"]
        ]
        
        XCTAssertThrowsError(try JSONMatcher(json: json))
        
        // Invalid scope value
        json = [
            "value": ["equals": "cool"],
            "key": 123,
            "scope": []
        ]
        XCTAssertThrowsError(try JSONMatcher(json: json))
        XCTAssertThrowsError(try JSONMatcher(json: ["not cool"]))
    }
}

extension Dictionary {
    func toNsDictionary() -> NSDictionary {
        return NSDictionary(dictionary: self)
    }
}
