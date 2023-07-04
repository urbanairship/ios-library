/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class DeviceTagSelectorTest: XCTestCase {

    func testCodable() throws {
        let json: String = """
        {
           "or":[
              {
                 "and":[
                    {
                       "tag":"some-tag"
                    },
                    {
                       "not":{
                          "tag":"not-tag"
                       }
                    }
                 ]
              },
              {
                 "tag":"some-other-tag"
              }
           ]
        }
        """

        let decoded: DeviceTagSelector = try JSONDecoder().decode(
            DeviceTagSelector.self,
            from: json.data(using: .utf8)!
        )

        let expected = DeviceTagSelector.or(
            [
                .and([.tag("some-tag"), .not(.tag("not-tag"))]),
                .tag("some-other-tag")
            ]
        )

        XCTAssertEqual(decoded, expected)

        let encoded = String(data: try JSONEncoder().encode(decoded), encoding: .utf8)
        XCTAssertEqual(try AirshipJSON.from(json: json), try AirshipJSON.from(json: encoded))
    }

    func testEvaluate() {
        let selector = DeviceTagSelector.or(
            [
                .and([.tag("some-tag"), .not(.tag("not-tag"))]),
                .tag("some-other-tag")
            ]
        )

        XCTAssertFalse(selector.evaluate(tags: Set()))
        XCTAssertTrue(selector.evaluate(tags: Set<String>(["some-tag"])))
        XCTAssertTrue(selector.evaluate(tags: Set<String>(["some-other-tag"])))
        XCTAssertTrue(selector.evaluate(tags: Set<String>(["some-other-tag", "not-tag"])))
        XCTAssertFalse(selector.evaluate(tags: Set<String>(["some-tag", "not-tag"])))
        XCTAssertFalse(selector.evaluate(tags: Set<String>(["not-tag"])))
    }
}
