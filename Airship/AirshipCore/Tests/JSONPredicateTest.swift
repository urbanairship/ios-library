/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class JSONPredicateTest: XCTestCase {

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

}
