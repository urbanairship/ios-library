/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class JsonMatcherTest: XCTestCase {

    var subject = JSONValueMatcher.matcherWhereStringEquals("cool")

    func testMatcherOnly() throws {
        let matcher = JSONMatcher(valueMatcher: subject)
        XCTAssertNotNil(matcher)

        XCTAssertTrue(matcher.evaluate(json: try! AirshipJSON.wrap("cool")))

        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap(nil)))
        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap(matcher)))
        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap("not cool")))
        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap(1)))
        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap(true)))
    }

    func testMatcherOnlyIgnoreCase() throws {
        let matcher = JSONMatcher(valueMatcher: subject, ignoreCase: true)

        XCTAssertNotNil(matcher)
        XCTAssertTrue(matcher.evaluate(json: try! AirshipJSON.wrap("cool")))
        XCTAssertTrue(matcher.evaluate(json: try! AirshipJSON.wrap("COOL")))
        XCTAssertTrue(matcher.evaluate(json: try! AirshipJSON.wrap("CooL")))

        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap(nil)))
        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap(matcher)))
        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap("not cool")))
        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap("NOT COOL")))
        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap(["property": "cool"])))
        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap(1)))
        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap(true)))
    }

    func testMatcherOnlyPayload() throws {
        let json = """
        {
            "value": {
                "equals": "cool"
            }
        }
        """
        let matcher = JSONMatcher(valueMatcher: subject)

        XCTAssertEqual(try AirshipJSON.from(json: json), try AirshipJSON.wrap(matcher))

        let fromJSON: JSONMatcher = try AirshipJSON.from(json: json).decode()
        XCTAssertEqual(matcher, fromJSON)
    }

    func testMatcherOnlyIgnoreCasePayload() throws {
        let json = """
        {
            "value": { 
                "equals": "cool"
            },
            "ignore_case": true    
        }
        """


        let matcher = JSONMatcher(valueMatcher: subject, ignoreCase: true)
        XCTAssertEqual(try AirshipJSON.from(json: json), try AirshipJSON.wrap(matcher))

        // Verify a matcher created from the JSON matches
        var fromJsonMatcher: JSONMatcher = try AirshipJSON.from(json: json).decode()
        XCTAssertNotNil(fromJsonMatcher)
        XCTAssertEqual(fromJsonMatcher, matcher)

        // Verify a matcher created from the JSON from the first matcher matches
        fromJsonMatcher = try AirshipJSON.wrap(matcher).decode()
        XCTAssertNotNil(fromJsonMatcher)
        XCTAssertEqual(fromJsonMatcher, matcher)
    }

    func testMatcherOnlyPayloadWithUnknownKey() throws {
        let json = """
        {
            "value": { 
                "equals": "cool"
            },
            "unknown": true    
        }
        """

        let matcher = JSONMatcher(valueMatcher: subject)
        XCTAssertNotNil(matcher)

        // Verify a matcher created from the JSON matches
        var fromJsonMatcher: JSONMatcher = try AirshipJSON.from(json: json).decode()
        XCTAssertNotNil(fromJsonMatcher)
        XCTAssertEqual(fromJsonMatcher, matcher)

        // Verify a matcher created from the JSON from the first matcher matches
        fromJsonMatcher = try AirshipJSON.wrap(matcher).decode()
        XCTAssertNotNil(fromJsonMatcher)
        XCTAssertEqual(fromJsonMatcher, matcher)
    }

    func testMatcherWithKey() throws {
        let matcher = JSONMatcher(valueMatcher: subject, scope: ["property"])
        XCTAssertTrue(matcher.evaluate(json: try! AirshipJSON.wrap(["property": "cool"])))

        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap("property")))
        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap(["property": "not cool"])))
        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap(nil)))
        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap(matcher)))
        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap("not cool")))
        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap(1)))
        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap(true)))
    }

    func testMatcherWithScopeIgnoreCase() throws {
        let matcher = JSONMatcher(valueMatcher: subject, scope: ["property"], ignoreCase: true)
        XCTAssertTrue(matcher.evaluate(json: try! AirshipJSON.wrap(["property": "cool"])))
        XCTAssertTrue(matcher.evaluate(json: try! AirshipJSON.wrap(["property": "COOL"])))
        XCTAssertTrue(matcher.evaluate(json: try! AirshipJSON.wrap(["property": "CooL"])))

        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap("property")))
        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap(["property": "not cool"])))
        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap(["property": "NOT COOL"])))
        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap(nil)))
        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap(matcher)))
        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap("not cool")))
        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap(1)))
        XCTAssertFalse(matcher.evaluate(json: try! AirshipJSON.wrap(true)))
    }

    func testScopeAsString() throws {
        let json = """
        {
            "value": { 
                "equals": "cool"
            },
            "key": "subproperty",
            "scope": ["property"]  
        }
        """

        let fromJSON: JSONMatcher = try AirshipJSON.from(json: json).decode()

        XCTAssertEqual(try AirshipJSON.from(json: json), try AirshipJSON.wrap(fromJSON))
    }

    func testInvalidKey() {
        // Invalid key value
        let json = """
        {
            "value": { "equals": "cool" },
            "key": 123,
            "scope": ["property"]
        }
        """

        do {
            let _: JSONMatcher = try AirshipJSON.from(json: json).decode()
            XCTFail()
        } catch {}
    }

    func testInvalidPayload() {
        let json = """
        {
            "not": "cool"
        }
        """

        do {
            let _: JSONMatcher = try AirshipJSON.from(json: json).decode()
            XCTFail()
        } catch {}

    }
}
