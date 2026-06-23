/* Copyright Airship and Contributors */

import Testing
import Foundation
@testable import AirshipBasement

struct JsonMatcherTest {

    let subject = JSONValueMatcher.matcherWhereStringEquals("cool")

    @Test
    func matcherOnly() throws {
        let matcher = JSONMatcher(valueMatcher: subject)

        #expect(matcher.evaluate(json: try! AirshipJSON.wrap("cool")))

        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap(nil)))
        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap(matcher)))
        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap("not cool")))
        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap(1)))
        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap(true)))
    }

    @Test
    func matcherOnlyIgnoreCase() throws {
        let matcher = JSONMatcher(valueMatcher: subject, ignoreCase: true)

        #expect(matcher.evaluate(json: try! AirshipJSON.wrap("cool")))
        #expect(matcher.evaluate(json: try! AirshipJSON.wrap("COOL")))
        #expect(matcher.evaluate(json: try! AirshipJSON.wrap("CooL")))

        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap(nil)))
        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap(matcher)))
        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap("not cool")))
        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap("NOT COOL")))
        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap(["property": "cool"])))
        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap(1)))
        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap(true)))
    }

    @Test
    func matcherOnlyPayload() throws {
        let json = """
        {
            "value": {
                "equals": "cool"
            }
        }
        """
        let matcher = JSONMatcher(valueMatcher: subject)

        #expect(try AirshipJSON.from(json: json) == (try AirshipJSON.wrap(matcher)))

        let fromJSON: JSONMatcher = try AirshipJSON.from(json: json).decode()
        #expect(matcher == fromJSON)
    }

    @Test
    func matcherOnlyIgnoreCasePayload() throws {
        let json = """
        {
            "value": {
                "equals": "cool"
            },
            "ignore_case": true
        }
        """


        let matcher = JSONMatcher(valueMatcher: subject, ignoreCase: true)
        #expect(try AirshipJSON.from(json: json) == (try AirshipJSON.wrap(matcher)))

        // Verify a matcher created from the JSON matches
        var fromJsonMatcher: JSONMatcher = try AirshipJSON.from(json: json).decode()
        #expect(fromJsonMatcher == matcher)

        // Verify a matcher created from the JSON from the first matcher matches
        fromJsonMatcher = try AirshipJSON.wrap(matcher).decode()
        #expect(fromJsonMatcher == matcher)
    }

    @Test
    func matcherOnlyPayloadWithUnknownKey() throws {
        let json = """
        {
            "value": {
                "equals": "cool"
            },
            "unknown": true
        }
        """

        let matcher = JSONMatcher(valueMatcher: subject)

        // Verify a matcher created from the JSON matches
        var fromJsonMatcher: JSONMatcher = try AirshipJSON.from(json: json).decode()
        #expect(fromJsonMatcher == matcher)

        // Verify a matcher created from the JSON from the first matcher matches
        fromJsonMatcher = try AirshipJSON.wrap(matcher).decode()
        #expect(fromJsonMatcher == matcher)
    }

    @Test
    func matcherWithKey() throws {
        let matcher = JSONMatcher(valueMatcher: subject, scope: ["property"])
        #expect(matcher.evaluate(json: try! AirshipJSON.wrap(["property": "cool"])))

        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap("property")))
        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap(["property": "not cool"])))
        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap(nil)))
        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap(matcher)))
        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap("not cool")))
        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap(1)))
        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap(true)))
    }

    @Test
    func matcherWithScopeIgnoreCase() throws {
        let matcher = JSONMatcher(valueMatcher: subject, scope: ["property"], ignoreCase: true)
        #expect(matcher.evaluate(json: try! AirshipJSON.wrap(["property": "cool"])))
        #expect(matcher.evaluate(json: try! AirshipJSON.wrap(["property": "COOL"])))
        #expect(matcher.evaluate(json: try! AirshipJSON.wrap(["property": "CooL"])))

        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap("property")))
        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap(["property": "not cool"])))
        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap(["property": "NOT COOL"])))
        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap(nil)))
        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap(matcher)))
        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap("not cool")))
        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap(1)))
        #expect(!matcher.evaluate(json: try! AirshipJSON.wrap(true)))
    }

    @Test
    func scopeAsString() throws {
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

        #expect(try AirshipJSON.from(json: json) == (try AirshipJSON.wrap(fromJSON)))
    }

    @Test
    func invalidKey() {
        // Invalid key value
        let json = """
        {
            "value": { "equals": "cool" },
            "key": 123,
            "scope": ["property"]
        }
        """

        #expect(throws: (any Error).self) {
            let _: JSONMatcher = try AirshipJSON.from(json: json).decode()
        }
    }

    @Test
    func invalidPayload() {
        let json = """
        {
            "not": "cool"
        }
        """

        #expect(throws: (any Error).self) {
            let _: JSONMatcher = try AirshipJSON.from(json: json).decode()
        }
    }
}
