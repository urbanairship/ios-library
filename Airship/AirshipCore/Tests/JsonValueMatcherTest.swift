/* Copyright Airship and Contributors */

import XCTest
import AirshipCore

final class JsonValueMatcherTest: XCTestCase {
    
    func testEqualsString() {
        let matcher = JSONValueMatcher.matcherWhereStringEquals("cool")
        XCTAssertTrue(matcher.evaluate("cool"))
        XCTAssertTrue(matcher.evaluate("cool", ignoreCase:false))
        XCTAssertTrue(matcher.evaluate("cool", ignoreCase:true))
        XCTAssertTrue(matcher.evaluate("COOL", ignoreCase:true))
        XCTAssertTrue(matcher.evaluate("CooL", ignoreCase:true))

        XCTAssertFalse(matcher.evaluate(nil))
        XCTAssertFalse(matcher.evaluate(matcher))
        XCTAssertFalse(matcher.evaluate("COOL"))
        XCTAssertFalse(matcher.evaluate("CooL"))
        XCTAssertFalse(matcher.evaluate("NOT COOL"))
        XCTAssertFalse(matcher.evaluate("not cool"))
        XCTAssertFalse(matcher.evaluate(1))
        XCTAssertFalse(matcher.evaluate(true))

        XCTAssertFalse(matcher.evaluate(nil, ignoreCase: false))
        XCTAssertFalse(matcher.evaluate(matcher, ignoreCase:false))
        XCTAssertFalse(matcher.evaluate("COOL", ignoreCase:false))
        XCTAssertFalse(matcher.evaluate("CooL", ignoreCase:false))
        XCTAssertFalse(matcher.evaluate("NOT COOL", ignoreCase:false))
        XCTAssertFalse(matcher.evaluate("not cool", ignoreCase:false))
        XCTAssertFalse(matcher.evaluate(1, ignoreCase:false))
        XCTAssertFalse(matcher.evaluate(true, ignoreCase:false))

        XCTAssertFalse(matcher.evaluate(nil, ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(matcher, ignoreCase:true))
        XCTAssertFalse(matcher.evaluate("NOT COOL", ignoreCase:true))
        XCTAssertFalse(matcher.evaluate("not cool", ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(1, ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(true, ignoreCase:true))
    }
    
    func testEqualsStringPayload() throws {
        let json = ["equals": "cool"]
        let matcher = JSONValueMatcher.matcherWhereStringEquals("cool")
        
        // Verify the JSONValue recreates the expected matcher
        XCTAssertEqual(matcher, try! JSONValueMatcher.matcherWithJSON(json))
    }
    
    func testEqualsBoolean() {
        let matcher = JSONValueMatcher.matcherWhereBooleanEquals(false)
        XCTAssertTrue(matcher.evaluate(false))
        XCTAssertTrue(matcher.evaluate(false, ignoreCase:true))
        XCTAssertTrue(matcher.evaluate(false, ignoreCase:false))

        XCTAssertFalse(matcher.evaluate(nil))
        XCTAssertFalse(matcher.evaluate(matcher))
        XCTAssertFalse(matcher.evaluate("not cool"))
        XCTAssertFalse(matcher.evaluate(1))
        XCTAssertFalse(matcher.evaluate(true))
        XCTAssertFalse(matcher.evaluate(true, ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(true, ignoreCase:false))
    }
    
    func testEqualsBooleanPayload() throws {
        let json = ["equals": true]
        let matcher = JSONValueMatcher.matcherWhereBooleanEquals(true)
        
        // Verify the JSONValue recreates the expected matcher
        XCTAssertEqual(matcher, try! JSONValueMatcher.matcherWithJSON(json))
    }
    
    func testEqualsNumber() {
        let matcher = JSONValueMatcher.matcherWhereNumberEquals(123.35)
        XCTAssertTrue(matcher.evaluate(123.35))
        XCTAssertTrue(matcher.evaluate(123.350))
        XCTAssertTrue(matcher.evaluate(123.350, ignoreCase:true))
        XCTAssertTrue(matcher.evaluate(123.350, ignoreCase:false))

        XCTAssertFalse(matcher.evaluate(nil))
        XCTAssertFalse(matcher.evaluate(matcher))
        XCTAssertFalse(matcher.evaluate("not cool"))
        XCTAssertFalse(matcher.evaluate(123))
        XCTAssertFalse(matcher.evaluate(123.3))
        XCTAssertFalse(matcher.evaluate(123.3, ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(123.3, ignoreCase:false))
        XCTAssertFalse(matcher.evaluate(true))
    }
    
    func testEqualsNumberPayload() throws {
        let json: [String: Any] = ["equals": 123.456]
        let match = JSONValueMatcher.matcherWhereNumberEquals(123.456)
        
        // Verify the JSONValue recreates the expected matcher
        XCTAssertEqual(match, try! JSONValueMatcher.matcherWithJSON(json))
    }
    
    func testAtLeast() {
        let matcher = JSONValueMatcher.matcherWhereNumberAtLeast(atLeast: 123.35)
        XCTAssertTrue(matcher.evaluate(123.35))
        XCTAssertTrue(matcher.evaluate(123.36))
        XCTAssertTrue(matcher.evaluate(123.36, ignoreCase:true))
        XCTAssertTrue(matcher.evaluate(123.36, ignoreCase:false))

        XCTAssertFalse(matcher.evaluate(nil))
        XCTAssertFalse(matcher.evaluate(matcher))
        XCTAssertFalse(matcher.evaluate("not cool"))
        XCTAssertFalse(matcher.evaluate(123))
        XCTAssertFalse(matcher.evaluate(123.3))
        XCTAssertFalse(matcher.evaluate(123.3, ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(123.3, ignoreCase:false))
        XCTAssertFalse(matcher.evaluate(true))
    }
    
    func testAtLeastPayload() throws {
        let json = ["at_least": 100]
        let matcher = JSONValueMatcher.matcherWhereNumberAtLeast(atLeast: 100)
        
        // Verify the JSONValue recreates the expected matcher
        XCTAssertEqual(matcher, try! JSONValueMatcher.matcherWithJSON(json))
    }
    
    func testAtMost() {
        let matcher = JSONValueMatcher.matcherWhereNumberAtMost(atMost: 123.35)
        XCTAssertTrue(matcher.evaluate(123.35))
        XCTAssertTrue(matcher.evaluate(123.34))
        XCTAssertTrue(matcher.evaluate(123.34, ignoreCase:true))
        XCTAssertTrue(matcher.evaluate(123.34, ignoreCase:false))

        XCTAssertFalse(matcher.evaluate(nil))
        XCTAssertFalse(matcher.evaluate(matcher))
        XCTAssertFalse(matcher.evaluate("not cool"))
        XCTAssertFalse(matcher.evaluate(123.36))
        XCTAssertFalse(matcher.evaluate(123.36, ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(123.36, ignoreCase:false))
        XCTAssertFalse(matcher.evaluate(124))
    }
    
    func testAtMostPayload() throws {
        let json = ["at_most": 100]
        let matcher = JSONValueMatcher.matcherWhereNumberAtMost(atMost: 100)
        
        // Verify the JSONValue recreates the expected matcher
        XCTAssertEqual(matcher, try! JSONValueMatcher.matcherWithJSON(json))
    }
    
    func testAtLeastAtMost() {
        let matcher = JSONValueMatcher.matcherWhereNumberAtLeast(atLeast: 100, atMost: 150)
        XCTAssertTrue(matcher.evaluate(100))
        XCTAssertTrue(matcher.evaluate(150))
        XCTAssertTrue(matcher.evaluate(123.456))
        XCTAssertTrue(matcher.evaluate(123.456, ignoreCase:true))
        XCTAssertTrue(matcher.evaluate(123.456, ignoreCase:false))

        XCTAssertFalse(matcher.evaluate(nil))
        XCTAssertFalse(matcher.evaluate(matcher))
        XCTAssertFalse(matcher.evaluate("not cool"))
        XCTAssertFalse(matcher.evaluate(99))
        XCTAssertFalse(matcher.evaluate(151))
        XCTAssertFalse(matcher.evaluate(151, ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(151, ignoreCase:false))
    }
    
    func testAtLeastAtMostPayload() throws {
        let json = ["at_least": 1, "at_most": 100]
        let matcher = JSONValueMatcher.matcherWhereNumberAtLeast(atLeast: 1, atMost: 100)
        
        // Verify the JSONValue recreates the expected matcher
        XCTAssertEqual(matcher, try! JSONValueMatcher.matcherWithJSON(json))
    }
    
    func testPresence() {
        let matcher = JSONValueMatcher.matcherWhereValueIsPresent(true)
        XCTAssertTrue(matcher.evaluate(100))
        XCTAssertTrue(matcher.evaluate(matcher))
        XCTAssertTrue(matcher.evaluate("cool"))
        XCTAssertTrue(matcher.evaluate("cool", ignoreCase:true))
        XCTAssertTrue(matcher.evaluate("cool", ignoreCase:true))

        XCTAssertFalse(matcher.evaluate(nil))
        XCTAssertFalse(matcher.evaluate(nil, ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(nil, ignoreCase:false))
    }
    
    func testPresencePayload() throws {
        let json = ["is_present": true]
        let matcher = JSONValueMatcher.matcherWhereValueIsPresent(true)
        
        // Verify the JSONValue recreates the expected matcher
        XCTAssertEqual(matcher, try! JSONValueMatcher.matcherWithJSON(json))
    }
    
    func testAbsence() {
        let matcher = JSONValueMatcher.matcherWhereValueIsPresent(false)
        XCTAssertTrue(matcher.evaluate(nil))
        XCTAssertTrue(matcher.evaluate(nil, ignoreCase:true))
        XCTAssertTrue(matcher.evaluate(nil, ignoreCase:false))

        XCTAssertFalse(matcher.evaluate(100))
        XCTAssertFalse(matcher.evaluate(matcher))
        XCTAssertFalse(matcher.evaluate("cool"))
        XCTAssertFalse(matcher.evaluate("cool", ignoreCase:true))
        XCTAssertFalse(matcher.evaluate("cool", ignoreCase:true))
    }
    
    func testAbsencePayload() throws {
        let json = ["is_present": false]
        let matcher = JSONValueMatcher.matcherWhereValueIsPresent(false)
        
        // Verify the JSONValue recreates the expected matcher
        XCTAssertEqual(matcher, try! JSONValueMatcher.matcherWithJSON(json))
    }
    
    func testVersionRangeConstraints() {
        var matcher = JSONValueMatcher.matcherWithVersionConstraint("1.0")!
        XCTAssertTrue(matcher.evaluate("1.0"))
        XCTAssertTrue(matcher.evaluate("1.0", ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(" 2.0 "))
        XCTAssertFalse(matcher.evaluate(" 2.0 ", ignoreCase:true))

        matcher = JSONValueMatcher.matcherWithVersionConstraint("1.0+")!
        XCTAssertTrue(matcher.evaluate("1.0"))
        XCTAssertTrue(matcher.evaluate("1.0.0"))
        XCTAssertTrue(matcher.evaluate("1.0", ignoreCase:true))
        XCTAssertFalse(matcher.evaluate("2"))
        XCTAssertFalse(matcher.evaluate("2", ignoreCase:true))

        matcher = JSONValueMatcher.matcherWithVersionConstraint("[1.0,2.0]")!
        XCTAssertTrue(matcher.evaluate("1.0"))
        XCTAssertTrue(matcher.evaluate("1.0.0"))
        XCTAssertTrue(matcher.evaluate("1.0", ignoreCase:true))
        XCTAssertTrue(matcher.evaluate("2.0.0"))
        XCTAssertFalse(matcher.evaluate("2.0.1"))
        XCTAssertFalse(matcher.evaluate("2.0.1",  ignoreCase:true))
    }
    
    func testArrayContains() throws {
        let valueMatcher = JSONValueMatcher.matcherWhereStringEquals("bingo")
        var jsonMatcher = JSONMatcher(valueMatcher: valueMatcher)
        var predicate = JSONPredicate(jsonMatcher: jsonMatcher)
        var matcher = JSONValueMatcher.matcherWithArrayContainsPredicate(predicate)!
        
        // Invalid values
        XCTAssertFalse(matcher.evaluate("1.0"))
        XCTAssertFalse(matcher.evaluate(["bingo": "what"]))
        XCTAssertFalse(matcher.evaluate(["BINGO": "what"], ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(1))
        XCTAssertFalse(matcher.evaluate(nil))
        
        var value = ["thats", "a", "BINGO"]
        XCTAssertFalse(matcher.evaluate(value))
        XCTAssertFalse(matcher.evaluate(value, ignoreCase:false))
        XCTAssertFalse(matcher.evaluate(value, ignoreCase:true))
        value = ["thats", "a"]
        XCTAssertFalse(matcher.evaluate(value))
        value = []
        XCTAssertFalse(matcher.evaluate([]))

        // Valid values
        value = ["thats", "a", "bingo"]
        XCTAssertTrue(matcher.evaluate(value))
        XCTAssertTrue(matcher.evaluate(value, ignoreCase:false))
        XCTAssertTrue(matcher.evaluate(value, ignoreCase:true))
        
        // ignore case
        jsonMatcher = JSONMatcher(valueMatcher: valueMatcher, ignoreCase: true)
        predicate = JSONPredicate(jsonMatcher: jsonMatcher)
        matcher = JSONValueMatcher.matcherWithArrayContainsPredicate(predicate)!
        
        value = ["thats", "a", "BINGO"]
        XCTAssertTrue(matcher.evaluate(value))
        XCTAssertTrue(matcher.evaluate(value, ignoreCase:false))
        XCTAssertTrue(matcher.evaluate(value, ignoreCase:true))
    }
    
    func testArrayContainsAtIndex() {
        let valueMatcher = JSONValueMatcher.matcherWhereStringEquals("bingo")
        var jsonMatcher = JSONMatcher(valueMatcher: valueMatcher)
        var predicate = JSONPredicate(jsonMatcher: jsonMatcher)
        var matcher = JSONValueMatcher.matcherWithArrayContainsPredicate(predicate, at: 1)!
        
        // Invalid values
        XCTAssertFalse(matcher.evaluate("1.0"))
        XCTAssertFalse(matcher.evaluate(["bingo": "what"]))
        XCTAssertFalse(matcher.evaluate(["bingo": "what"], ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(1))
        XCTAssertFalse(matcher.evaluate(nil))
        
        var value = ["thats", "a", "BINGO"]
        XCTAssertFalse(matcher.evaluate(value))
        XCTAssertFalse(matcher.evaluate(value, ignoreCase:false))
        XCTAssertFalse(matcher.evaluate(value, ignoreCase:true))
        
        value = ["thats", "a"]
        XCTAssertFalse(matcher.evaluate(value))
        
        value = []
        XCTAssertFalse(matcher.evaluate(value))
        
        value = ["thats", "BINGO", "a"]
        XCTAssertFalse(matcher.evaluate(value))
        XCTAssertFalse(matcher.evaluate(value, ignoreCase:false))
        XCTAssertFalse(matcher.evaluate(value, ignoreCase:true))

        // Valid values
        value = ["thats", "bingo", "a"]
        XCTAssertTrue(matcher.evaluate(value))
        
        value = ["thats", "bingo"]
        XCTAssertTrue(matcher.evaluate(value))
        
        value = ["a", "bingo"]
        XCTAssertTrue(matcher.evaluate(value))

        // ignore case
        jsonMatcher = JSONMatcher(valueMatcher: valueMatcher, ignoreCase: true)
        predicate = JSONPredicate(jsonMatcher: jsonMatcher)
        matcher = JSONValueMatcher.matcherWithArrayContainsPredicate(predicate, at: 1)!
        
        value = ["thats", "a", "BINGO"]
        XCTAssertFalse(matcher.evaluate(value))
        XCTAssertFalse(matcher.evaluate(value, ignoreCase:false))
        XCTAssertFalse(matcher.evaluate(value, ignoreCase:true))

        value = ["thats", "BINGO", "a"]
        XCTAssertTrue(matcher.evaluate(value))
        XCTAssertTrue(matcher.evaluate(value, ignoreCase:false))
        XCTAssertTrue(matcher.evaluate(value, ignoreCase:true))
    }
    
    func testVersionMatcher() throws {
        var matcher = try! JSONValueMatcher.matcherWithJSON(["version_matches": "9.9"])
        XCTAssertFalse(matcher.evaluate("9.0"))
        XCTAssertTrue(matcher.evaluate("9.9"))
        XCTAssertTrue(matcher.evaluate("9.9", ignoreCase:true))
        XCTAssertFalse(matcher.evaluate("10.0"))
        XCTAssertFalse(matcher.evaluate("10.0", ignoreCase:true))

        matcher = try! JSONValueMatcher.matcherWithJSON(["version_matches": "8.9"])
        XCTAssertFalse(matcher.evaluate("8.0"))
        XCTAssertTrue(matcher.evaluate("8.9"))
        XCTAssertFalse(matcher.evaluate("9.0"))
    }
    
    func testInvalidPayload() {
        // Invalid object
        XCTAssertThrowsError(try JSONValueMatcher.matcherWithJSON("cool"))
    }
}
