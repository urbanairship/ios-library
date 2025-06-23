/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class JsonValueMatcherTest: XCTestCase {

    func testEqualsString() throws {
        let matcher = JSONValueMatcher.matcherWhereStringEquals("cool")
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap("cool")))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap("cool"), ignoreCase:false))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap("cool"), ignoreCase:true))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap("COOL"), ignoreCase:true))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap("CooL"), ignoreCase:true))

        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(nil)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(matcher)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("COOL")))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("CooL")))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("NOT COOL")))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("not cool")))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(1)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(true)))

        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(nil), ignoreCase: false))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(matcher), ignoreCase:false))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("COOL"), ignoreCase:false))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("CooL"), ignoreCase:false))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("NOT COOL"), ignoreCase:false))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("not cool"), ignoreCase:false))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(1), ignoreCase:false))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(true), ignoreCase:false))

        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(nil), ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(matcher), ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("NOT COOL"), ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("not cool"), ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(1), ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(true), ignoreCase:true))
    }

    func testEqualsStringPayload() throws {
        let json = """
        {
            "equals": "cool"
        }
        """
        let matcher = JSONValueMatcher.matcherWhereStringEquals("cool")

        // Verify the JSONValue recreates the expected matcher
        XCTAssertEqual(matcher, try AirshipJSON.from(json: json).decode())
    }

    func testEqualsBoolean() throws {
        let matcher = JSONValueMatcher.matcherWhereBooleanEquals(false)
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(false)))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(false), ignoreCase:true))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(false), ignoreCase:false))

        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(nil)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(matcher)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("not cool")))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(1)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(true)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(true), ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(true), ignoreCase:false))
    }

    func testEqualsBooleanPayload() throws {
        let json = """
        {
            "equals": true
        }
        """

        let matcher = JSONValueMatcher.matcherWhereBooleanEquals(true)

        // Verify the JSONValue recreates the expected matcher
        XCTAssertEqual(matcher, try AirshipJSON.from(json: json).decode())
    }

    func testEqualsNumber() throws {
        let matcher = JSONValueMatcher.matcherWhereNumberEquals(123.35)
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(123.35)))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(123.350)))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(123.350), ignoreCase:true))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(123.350), ignoreCase:false))

        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(nil)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(matcher)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("not cool")))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(123)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(123.3)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(123.3), ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(123.3), ignoreCase:false))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(true)))
    }

    func testEqualsNumberPayload() throws {
        let json = """
        {
            "equals": 123.456
        }
        """
        let match = JSONValueMatcher.matcherWhereNumberEquals(123.456)

        // Verify the JSONValue recreates the expected matcher
        XCTAssertEqual(match, try AirshipJSON.from(json: json).decode())
    }

    func testAtLeast() throws {
        let matcher = JSONValueMatcher.matcherWhereNumberAtLeast(atLeast: 123.35)
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(123.35)))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(123.36)))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(123.36), ignoreCase:true))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(123.36), ignoreCase:false))

        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(nil)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(matcher)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("not cool")))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(123)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(123.3)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(123.3), ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(123.3), ignoreCase:false))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(true)))
    }

    func testAtLeastPayload() throws {
        let json = """
        {
            "at_least": 100
        }
        """

        let matcher = JSONValueMatcher.matcherWhereNumberAtLeast(atLeast: 100)

        // Verify the JSONValue recreates the expected matcher
        XCTAssertEqual(matcher, try AirshipJSON.from(json: json).decode())
    }

    func testAtMost() throws {
        let matcher = JSONValueMatcher.matcherWhereNumberAtMost(atMost: 123.35)
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(123.35)))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(123.34)))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(123.34), ignoreCase:true))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(123.34), ignoreCase:false))

        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(nil)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(matcher)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("not cool")))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(123.36)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(123.36), ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(123.36), ignoreCase:false))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(124)))
    }

    func testAtMostPayload() throws {
        let json = """
        {
            "at_most": 100
        }
        """

        let matcher = JSONValueMatcher.matcherWhereNumberAtMost(atMost: 100)

        // Verify the JSONValue recreates the expected matcher
        XCTAssertEqual(matcher, try AirshipJSON.from(json: json).decode())
    }

    func testAtLeastAtMost() throws {
        let matcher = JSONValueMatcher.matcherWhereNumberAtLeast(atLeast: 100, atMost: 150)
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(100)))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(150)))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(123.456)))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(123.456), ignoreCase:true))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(123.456), ignoreCase:false))

        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(nil)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(matcher)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("not cool")))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(99)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(151)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(151), ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(151), ignoreCase:false))
    }

    func testAtLeastAtMostPayload() throws {
        let json = """
        {
            "at_least": 1,
            "at_most": 100
        }
        """
        let matcher = JSONValueMatcher.matcherWhereNumberAtLeast(atLeast: 1, atMost: 100)

        // Verify the JSONValue recreates the expected matcher
        XCTAssertEqual(matcher, try AirshipJSON.from(json: json).decode())
    }

    func testPresence() throws {
        let matcher = JSONValueMatcher.matcherWhereValueIsPresent(true)
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(100)))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(matcher)))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap("cool")))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap("cool"), ignoreCase:true))

        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(nil)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(nil), ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(nil), ignoreCase:false))
    }

    func testPresencePayload() throws {
        let json = """
        {
            "is_present": true
        }
        """
        let matcher = JSONValueMatcher.matcherWhereValueIsPresent(true)

        // Verify the JSONValue recreates the expected matcher
        XCTAssertEqual(matcher, try AirshipJSON.from(json: json).decode())
    }

    func testAbsence() throws {
        let matcher = JSONValueMatcher.matcherWhereValueIsPresent(false)
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(nil)))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(nil), ignoreCase:true))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(nil), ignoreCase:false))

        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(100)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(matcher)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("cool")))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("cool"), ignoreCase:true))
    }

    func testAbsencePayload() throws {
        let json = """
        {
            "is_present": false
        }
        """
        let matcher = JSONValueMatcher.matcherWhereValueIsPresent(false)

        // Verify the JSONValue recreates the expected matcher
        XCTAssertEqual(matcher, try AirshipJSON.from(json: json).decode())
    }

    func testVersionRangeConstraints() throws {
        var matcher = JSONValueMatcher.matcherWithVersionConstraint("1.0")!
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap("1.0")))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap("1.0"), ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(" 2.0 ")))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(" 2.0 "), ignoreCase:true))

        matcher = JSONValueMatcher.matcherWithVersionConstraint("1.0+")!
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap("1.0")))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap("1.0.0")))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap("1.0"), ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("2")))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("2"), ignoreCase:true))

        matcher = JSONValueMatcher.matcherWithVersionConstraint("[1.0,2.0]")!
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap("1.0")))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap("1.0.0")))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap("1.0"), ignoreCase:true))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap("2.0.0")))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("2.0.1")))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("2.0.1"), ignoreCase:true))
    }

    func testArrayContains() throws {
        let valueMatcher = JSONValueMatcher.matcherWhereStringEquals("bingo")
        var jsonMatcher = JSONMatcher(valueMatcher: valueMatcher)
        var predicate = JSONPredicate(jsonMatcher: jsonMatcher)
        var matcher = JSONValueMatcher.matcherWithArrayContainsPredicate(predicate)!

        // Invalid values
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("1.0")))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(["bingo": "what"])))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(["BINGO": "what"]), ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(1)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(nil)))

        var value = ["thats", "a", "BINGO"]
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(value)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:false))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:true))
        value = ["thats", "a"]
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(value)))
        value = []
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(value)))

        // Valid values
        value = ["thats", "a", "bingo"]
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(value)))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:false))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:true))

        // ignore case
        jsonMatcher = JSONMatcher(valueMatcher: valueMatcher, ignoreCase: true)
        predicate = JSONPredicate(jsonMatcher: jsonMatcher)
        matcher = JSONValueMatcher.matcherWithArrayContainsPredicate(predicate)!

        value = ["thats", "a", "BINGO"]
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(value)))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:false))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:true))
    }

    func testArrayContainsAtIndex() throws {
        let valueMatcher = JSONValueMatcher.matcherWhereStringEquals("bingo")
        var jsonMatcher = JSONMatcher(valueMatcher: valueMatcher)
        var predicate = JSONPredicate(jsonMatcher: jsonMatcher)
        var matcher = JSONValueMatcher.matcherWithArrayContainsPredicate(predicate, at: 1)!

        // Invalid values
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("1.0")))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(["bingo": "what"])))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(["bingo": "what"]), ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(1)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(nil)))

        var value = ["thats", "a", "BINGO"]
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(value)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:false))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:true))

        value = ["thats", "a"]
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(value)))

        value = []
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(value)))

        value = ["thats", "BINGO", "a"]
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(value)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:false))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:true))

        // Valid values
        value = ["thats", "bingo", "a"]
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(value)))

        value = ["thats", "bingo"]
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(value)))

        value = ["a", "bingo"]
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(value)))

        // ignore case
        jsonMatcher = JSONMatcher(valueMatcher: valueMatcher, ignoreCase: true)
        predicate = JSONPredicate(jsonMatcher: jsonMatcher)
        matcher = JSONValueMatcher.matcherWithArrayContainsPredicate(predicate, at: 1)!

        value = ["thats", "a", "BINGO"]
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(value)))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:false))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:true))

        value = ["thats", "BINGO", "a"]
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(value)))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:false))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap(value), ignoreCase:true))
    }

    func testVersionMatcher() throws {
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
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("9.0")))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap("9.9")))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap("9.9"), ignoreCase:true))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("10.0")))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("10.0"), ignoreCase:true))

        matcher = try AirshipJSON.from(json: jsonV8).decode()
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("8.0")))
        XCTAssertTrue(matcher.evaluate(json: try AirshipJSON.wrap("8.9")))
        XCTAssertFalse(matcher.evaluate(json: try AirshipJSON.wrap("9.0")))
    }

    func testInvalidPayload() {
        let invalid = """
        {
            "cool": "neat"
        }
        """

        // Invalid object
        do {
            let _: JSONValueMatcher = try AirshipJSON.from(json: invalid).decode()
            XCTFail()
        } catch {

        }
    }

    func testStringBeginsMatcherParsing() throws {
        let json = """
        {
            "string_begins": "neat"
        }
        """

        let fromJSON: JSONValueMatcher = try AirshipJSON.from(json: json).decode()
        let expected = JSONValueMatcher(
            predicate: JSONValueMatcher.StringBeginsPredicate(stringBegins: "neat")
        )
        XCTAssertEqual(fromJSON, expected)
    }

    func testStringEndsMatcherParsing() throws {
        let json = """
        {
            "string_ends": "neat"
        }
        """

        let fromJSON: JSONValueMatcher = try AirshipJSON.from(json: json).decode()
        let expected = JSONValueMatcher(
            predicate: JSONValueMatcher.StringEndsPredicate(stringEnds: "neat")
        )
        XCTAssertEqual(fromJSON, expected)
    }

    func testStringContainsMatcherParsing() throws {
        let json = """
        {
            "string_contains": "neat"
        }
        """

        let fromJSON: JSONValueMatcher = try AirshipJSON.from(json: json).decode()
        let expected = JSONValueMatcher(
            predicate: JSONValueMatcher.StringContainsPredicate(stringContains: "neat")
        )
        XCTAssertEqual(fromJSON, expected)
    }

    func testStringBeginsMatcher() throws {
        let matcher = JSONValueMatcher(
            predicate: JSONValueMatcher.StringBeginsPredicate(stringBegins: "foo")
        )
        XCTAssertTrue(matcher.evaluate(json: AirshipJSON.string("foobar")))
        XCTAssertTrue(matcher.evaluate(json: AirshipJSON.string("FOOBAR"), ignoreCase: true))
        XCTAssertFalse(matcher.evaluate(json: AirshipJSON.string("FOOBAR")))
        XCTAssertFalse(matcher.evaluate(json: AirshipJSON.string("barfoo")))
    }

    func testStringEndsMatcher() throws {
        let matcher = JSONValueMatcher(
            predicate: JSONValueMatcher.StringEndsPredicate(stringEnds: "bar")
        )
        XCTAssertTrue(matcher.evaluate(json: AirshipJSON.string("foobar")))
        XCTAssertTrue(matcher.evaluate(json: AirshipJSON.string("FOOBAR"), ignoreCase: true))
        XCTAssertFalse(matcher.evaluate(json: AirshipJSON.string("FOOBAR")))
        XCTAssertFalse(matcher.evaluate(json: AirshipJSON.string("barfoo")))
    }

    func testStringContainsMatcher() throws {
        let matcher = JSONValueMatcher(
            predicate: JSONValueMatcher.StringContainsPredicate(stringContains: "oob")
        )
        XCTAssertTrue(matcher.evaluate(json: AirshipJSON.string("foobar")))
        XCTAssertTrue(matcher.evaluate(json: AirshipJSON.string("FOOBAR"), ignoreCase: true))
        XCTAssertFalse(matcher.evaluate(json: AirshipJSON.string("FOOBAR")))
        XCTAssertFalse(matcher.evaluate(json: AirshipJSON.string("barfoo")))
    }

    func testStringEndsMatcherEdgeCase() throws {
        let matcher = JSONValueMatcher(
            predicate: JSONValueMatcher.StringEndsPredicate(stringEnds: "i")
        )
        XCTAssertFalse(matcher.evaluate(json: AirshipJSON.string("fooİ")))
        XCTAssertTrue(matcher.evaluate(json: AirshipJSON.string("fooİ"), ignoreCase: true))
    }

    func testStringBeginsMatcherEdgeCase() throws {
        let matcher = JSONValueMatcher(
            predicate: JSONValueMatcher.StringBeginsPredicate(stringBegins: "i")
        )
        XCTAssertFalse(matcher.evaluate(json: AirshipJSON.string("İfoo")))
        XCTAssertTrue(matcher.evaluate(json: AirshipJSON.string("İfoo"), ignoreCase: true))
    }

    func testStringContainsMatcherEdgeCase() throws {
        let matcher = JSONValueMatcher(
            predicate: JSONValueMatcher.StringContainsPredicate(stringContains: "i")
        )
        XCTAssertFalse(matcher.evaluate(json: AirshipJSON.string("fooİẞar")))
        XCTAssertTrue(matcher.evaluate(json: AirshipJSON.string("FOOİẞAR"), ignoreCase: true))
    }
}
