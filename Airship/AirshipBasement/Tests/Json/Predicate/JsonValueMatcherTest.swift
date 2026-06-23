/* Copyright Airship and Contributors */

import Testing
import Foundation
@testable import AirshipBasement

struct JsonValueMatcherTest {

    @Test
    func equalsString() throws {
        let matcher = JSONValueMatcher.matcherWhereStringEquals("cool")
        #expect(matcher.evaluate(json: try AirshipJSON.wrap("cool")))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap("cool"), ignoreCase:false))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap("cool"), ignoreCase:true))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap("COOL"), ignoreCase:true))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap("CooL"), ignoreCase:true))

        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(nil)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(matcher)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("COOL")))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("CooL")))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("NOT COOL")))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("not cool")))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(1)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(true)))

        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(nil), ignoreCase: false))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(matcher), ignoreCase:false))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("COOL"), ignoreCase:false))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("CooL"), ignoreCase:false))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("NOT COOL"), ignoreCase:false))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("not cool"), ignoreCase:false))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(1), ignoreCase:false))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(true), ignoreCase:false))

        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(nil), ignoreCase:true))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(matcher), ignoreCase:true))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("NOT COOL"), ignoreCase:true))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("not cool"), ignoreCase:true))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(1), ignoreCase:true))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(true), ignoreCase:true))
    }

    @Test
    func equalsStringPayload() throws {
        let json = """
        {
            "equals": "cool"
        }
        """
        let matcher = JSONValueMatcher.matcherWhereStringEquals("cool")

        // Verify the JSONValue recreates the expected matcher
        #expect(matcher == (try AirshipJSON.from(json: json).decode()))
    }

    @Test
    func equalsBoolean() throws {
        let matcher = JSONValueMatcher.matcherWhereBooleanEquals(false)
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(false)))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(false), ignoreCase:true))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(false), ignoreCase:false))

        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(nil)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(matcher)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("not cool")))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(1)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(true)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(true), ignoreCase:true))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(true), ignoreCase:false))
    }

    @Test
    func equalsBooleanPayload() throws {
        let json = """
        {
            "equals": true
        }
        """

        let matcher = JSONValueMatcher.matcherWhereBooleanEquals(true)

        // Verify the JSONValue recreates the expected matcher
        #expect(matcher == (try AirshipJSON.from(json: json).decode()))
    }

    @Test
    func equalsNumber() throws {
        let matcher = JSONValueMatcher.matcherWhereNumberEquals(to: 123.35)
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(123.35)))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(123.350)))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(123.350), ignoreCase:true))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(123.350), ignoreCase:false))

        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(nil)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(matcher)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("not cool")))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(123)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(123.3)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(123.3), ignoreCase:true))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(123.3), ignoreCase:false))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(true)))
    }

    @Test
    func equalsNumberPayload() throws {
        let json = """
        {
            "equals": 123.456
        }
        """
        let match = JSONValueMatcher.matcherWhereNumberEquals(to: 123.456)

        // Verify the JSONValue recreates the expected matcher
        #expect(match == (try AirshipJSON.from(json: json).decode()))
    }

    @Test
    func atLeast() throws {
        let matcher = JSONValueMatcher.matcherWhereNumberAtLeast(123.35)
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(123.35)))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(123.36)))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(123.36), ignoreCase:true))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(123.36), ignoreCase:false))

        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(nil)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(matcher)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("not cool")))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(123)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(123.3)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(123.3), ignoreCase:true))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(123.3), ignoreCase:false))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(true)))
    }

    @Test
    func atLeastPayload() throws {
        let json = """
        {
            "at_least": 100
        }
        """

        let matcher = JSONValueMatcher.matcherWhereNumberAtLeast(100)

        // Verify the JSONValue recreates the expected matcher
        #expect(matcher == (try AirshipJSON.from(json: json).decode()))
    }

    @Test
    func atMost() throws {
        let matcher = JSONValueMatcher.matcherWhereNumberAtMost(123.35)
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(123.35)))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(123.34)))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(123.34), ignoreCase:true))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(123.34), ignoreCase:false))

        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(nil)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(matcher)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("not cool")))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(123.36)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(123.36), ignoreCase:true))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(123.36), ignoreCase:false))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(124)))
    }

    @Test
    func atMostPayload() throws {
        let json = """
        {
            "at_most": 100
        }
        """

        let matcher = JSONValueMatcher.matcherWhereNumberAtMost(100)

        // Verify the JSONValue recreates the expected matcher
        #expect(matcher == (try AirshipJSON.from(json: json).decode()))
    }

    @Test
    func atLeastAtMost() throws {
        let matcher = JSONValueMatcher.matcherWhereNumberAtLeast(100, atMost: 150)
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(100)))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(150)))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(123.456)))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(123.456), ignoreCase:true))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(123.456), ignoreCase:false))

        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(nil)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(matcher)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("not cool")))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(99)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(151)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(151), ignoreCase:true))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(151), ignoreCase:false))
    }

    @Test
    func atLeastAtMostPayload() throws {
        let json = """
        {
            "at_least": 1,
            "at_most": 100
        }
        """
        let matcher = JSONValueMatcher.matcherWhereNumberAtLeast(1, atMost: 100)

        // Verify the JSONValue recreates the expected matcher
        #expect(matcher == (try AirshipJSON.from(json: json).decode()))
    }

    @Test
    func presence() throws {
        let matcher = JSONValueMatcher.matcherWhereValueIsPresent(true)
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(100)))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(matcher)))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap("cool")))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap("cool"), ignoreCase:true))

        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(nil)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(nil), ignoreCase:true))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(nil), ignoreCase:false))
    }

    @Test
    func presencePayload() throws {
        let json = """
        {
            "is_present": true
        }
        """
        let matcher = JSONValueMatcher.matcherWhereValueIsPresent(true)

        // Verify the JSONValue recreates the expected matcher
        #expect(matcher == (try AirshipJSON.from(json: json).decode()))
    }

    @Test
    func absence() throws {
        let matcher = JSONValueMatcher.matcherWhereValueIsPresent(false)
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(nil)))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(nil), ignoreCase:true))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(nil), ignoreCase:false))

        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(100)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(matcher)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("cool")))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("cool"), ignoreCase:true))
    }

    @Test
    func absencePayload() throws {
        let json = """
        {
            "is_present": false
        }
        """
        let matcher = JSONValueMatcher.matcherWhereValueIsPresent(false)

        // Verify the JSONValue recreates the expected matcher
        #expect(matcher == (try AirshipJSON.from(json: json).decode()))
    }

    @Test
    func versionRangeConstraints() throws {
        var matcher = JSONValueMatcher.matcherWithVersionConstraint("1.0")!
        #expect(matcher.evaluate(json: try AirshipJSON.wrap("1.0")))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap("1.0"), ignoreCase:true))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(" 2.0 ")))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(" 2.0 "), ignoreCase:true))

        matcher = JSONValueMatcher.matcherWithVersionConstraint("1.0+")!
        #expect(matcher.evaluate(json: try AirshipJSON.wrap("1.0")))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap("1.0.0")))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap("1.0"), ignoreCase:true))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("2")))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("2"), ignoreCase:true))

        matcher = JSONValueMatcher.matcherWithVersionConstraint("[1.0,2.0]")!
        #expect(matcher.evaluate(json: try AirshipJSON.wrap("1.0")))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap("1.0.0")))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap("1.0"), ignoreCase:true))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap("2.0.0")))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("2.0.1")))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("2.0.1"), ignoreCase:true))
    }

    @Test
    func arrayContains() throws {
        let valueMatcher = JSONValueMatcher.matcherWhereStringEquals("bingo")
        var jsonMatcher = JSONMatcher(valueMatcher: valueMatcher)
        var predicate = JSONPredicate(jsonMatcher: jsonMatcher)
        var matcher = JSONValueMatcher.matcherWithArrayContainsPredicate(predicate)!

        // Invalid values
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("1.0")))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(["bingo": "what"])))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(["BINGO": "what"]), ignoreCase:true))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(1)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(nil)))

        var value = ["thats", "a", "BINGO"]
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(value)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:false))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:true))
        value = ["thats", "a"]
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(value)))
        value = []
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(value)))

        // Valid values
        value = ["thats", "a", "bingo"]
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(value)))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:false))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:true))

        // ignore case
        jsonMatcher = JSONMatcher(valueMatcher: valueMatcher, ignoreCase: true)
        predicate = JSONPredicate(jsonMatcher: jsonMatcher)
        matcher = JSONValueMatcher.matcherWithArrayContainsPredicate(predicate)!

        value = ["thats", "a", "BINGO"]
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(value)))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:false))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:true))
    }

    @Test
    func arrayContainsAtIndex() throws {
        let valueMatcher = JSONValueMatcher.matcherWhereStringEquals("bingo")
        var jsonMatcher = JSONMatcher(valueMatcher: valueMatcher)
        var predicate = JSONPredicate(jsonMatcher: jsonMatcher)
        var matcher = JSONValueMatcher.matcherWithArrayContainsPredicate(predicate, at: 1)!

        // Invalid values
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("1.0")))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(["bingo": "what"])))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(["bingo": "what"]), ignoreCase:true))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(1)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(nil)))

        var value = ["thats", "a", "BINGO"]
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(value)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:false))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:true))

        value = ["thats", "a"]
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(value)))

        value = []
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(value)))

        value = ["thats", "BINGO", "a"]
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(value)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:false))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:true))

        // Valid values
        value = ["thats", "bingo", "a"]
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(value)))

        value = ["thats", "bingo"]
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(value)))

        value = ["a", "bingo"]
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(value)))

        // ignore case
        jsonMatcher = JSONMatcher(valueMatcher: valueMatcher, ignoreCase: true)
        predicate = JSONPredicate(jsonMatcher: jsonMatcher)
        matcher = JSONValueMatcher.matcherWithArrayContainsPredicate(predicate, at: 1)!

        value = ["thats", "a", "BINGO"]
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(value)))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:false))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:true))

        value = ["thats", "BINGO", "a"]
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(value)))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:false))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:true))
    }

    @Test
    func versionMatcher() throws {
        let jsonV9 = """
        {
            "version_matches": "9.9"
        }
        """

        let jsonV8 = """
        {
            "version_matches": "8.9"
        }
        """

        var matcher: JSONValueMatcher = try AirshipJSON.from(json: jsonV9).decode()
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("9.0")))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap("9.9")))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap("9.9"), ignoreCase:true))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("10.0")))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("10.0"), ignoreCase:true))

        matcher = try AirshipJSON.from(json: jsonV8).decode()
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("8.0")))
        #expect(matcher.evaluate(json: try AirshipJSON.wrap("8.9")))
        #expect(!matcher.evaluate(json: try AirshipJSON.wrap("9.0")))
    }

    @Test
    func invalidPayload() {
        let invalid = """
        {
            "cool": "neat"
        }
        """

        // Invalid object
        do {
            let _: JSONValueMatcher = try AirshipJSON.from(json: invalid).decode()
            Issue.record()
        } catch {

        }
    }

    @Test
    func stringBeginsMatcherParsing() throws {
        let json = """
        {
            "string_begins": "neat"
        }
        """

        let fromJSON: JSONValueMatcher = try AirshipJSON.from(json: json).decode()
        let expected = JSONValueMatcher(
            predicate: JSONValueMatcher.StringBeginsPredicate(stringBegins: "neat")
        )
        #expect(fromJSON == expected)
    }

    @Test
    func stringEndsMatcherParsing() throws {
        let json = """
        {
            "string_ends": "neat"
        }
        """

        let fromJSON: JSONValueMatcher = try AirshipJSON.from(json: json).decode()
        let expected = JSONValueMatcher(
            predicate: JSONValueMatcher.StringEndsPredicate(stringEnds: "neat")
        )
        #expect(fromJSON == expected)
    }

    @Test
    func stringContainsMatcherParsing() throws {
        let json = """
        {
            "string_contains": "neat"
        }
        """

        let fromJSON: JSONValueMatcher = try AirshipJSON.from(json: json).decode()
        let expected = JSONValueMatcher(
            predicate: JSONValueMatcher.StringContainsPredicate(stringContains: "neat")
        )
        #expect(fromJSON == expected)
    }

    @Test
    func stringBeginsMatcher() throws {
        let matcher = JSONValueMatcher(
            predicate: JSONValueMatcher.StringBeginsPredicate(stringBegins: "foo")
        )
        #expect(matcher.evaluate(json: AirshipJSON.string("foobar")))
        #expect(matcher.evaluate(json: AirshipJSON.string("FOOBAR"), ignoreCase: true))
        #expect(!matcher.evaluate(json: AirshipJSON.string("FOOBAR")))
        #expect(!matcher.evaluate(json: AirshipJSON.string("barfoo")))
    }

    @Test
    func stringEndsMatcher() throws {
        let matcher = JSONValueMatcher(
            predicate: JSONValueMatcher.StringEndsPredicate(stringEnds: "bar")
        )
        #expect(matcher.evaluate(json: AirshipJSON.string("foobar")))
        #expect(matcher.evaluate(json: AirshipJSON.string("FOOBAR"), ignoreCase: true))
        #expect(!matcher.evaluate(json: AirshipJSON.string("FOOBAR")))
        #expect(!matcher.evaluate(json: AirshipJSON.string("barfoo")))
    }

    @Test
    func stringContainsMatcher() throws {
        let matcher = JSONValueMatcher(
            predicate: JSONValueMatcher.StringContainsPredicate(stringContains: "oob")
        )
        #expect(matcher.evaluate(json: AirshipJSON.string("foobar")))
        #expect(matcher.evaluate(json: AirshipJSON.string("FOOBAR"), ignoreCase: true))
        #expect(!matcher.evaluate(json: AirshipJSON.string("FOOBAR")))
        #expect(!matcher.evaluate(json: AirshipJSON.string("barfoo")))
    }

    @Test
    func stringEndsMatcherEdgeCase() throws {
        let matcher = JSONValueMatcher(
            predicate: JSONValueMatcher.StringEndsPredicate(stringEnds: "i")
        )
        #expect(!matcher.evaluate(json: AirshipJSON.string("fooİ")))
        #expect(matcher.evaluate(json: AirshipJSON.string("fooİ"), ignoreCase: true))
    }

    @Test
    func stringBeginsMatcherEdgeCase() throws {
        let matcher = JSONValueMatcher(
            predicate: JSONValueMatcher.StringBeginsPredicate(stringBegins: "i")
        )
        #expect(!matcher.evaluate(json: AirshipJSON.string("İfoo")))
        #expect(matcher.evaluate(json: AirshipJSON.string("İfoo"), ignoreCase: true))
    }

    @Test
    func stringContainsMatcherEdgeCase() throws {
        let matcher = JSONValueMatcher(
            predicate: JSONValueMatcher.StringContainsPredicate(stringContains: "i")
        )
        #expect(!matcher.evaluate(json: AirshipJSON.string("fooİẞar")))
        #expect(matcher.evaluate(json: AirshipJSON.string("FOOİẞAR"), ignoreCase: true))
    }
}
