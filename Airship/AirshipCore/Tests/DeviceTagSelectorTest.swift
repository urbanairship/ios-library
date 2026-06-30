/* Copyright Airship and Contributors */

import Testing
@testable import AirshipCore
import Foundation

@Suite struct DeviceTagSelectorTest {

    @Test
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

        #expect(decoded == expected)

        let encoded = String(data: try JSONEncoder().encode(decoded), encoding: .utf8)
        #expect(try AirshipJSON.from(json: json) == AirshipJSON.from(json: encoded))
    }

    @Test
    func testEvaluate() {
        let selector = DeviceTagSelector.or(
            [
                .and([.tag("some-tag"), .not(.tag("not-tag"))]),
                .tag("some-other-tag")
            ]
        )

        #expect(!(selector.evaluate(tags: Set())))
        #expect(selector.evaluate(tags: Set<String>(["some-tag"])))
        #expect(selector.evaluate(tags: Set<String>(["some-other-tag"])))
        #expect(selector.evaluate(tags: Set<String>(["some-other-tag", "not-tag"])))
        #expect(!(selector.evaluate(tags: Set<String>(["some-tag", "not-tag"]))))
        #expect(!(selector.evaluate(tags: Set<String>(["not-tag"]))))
    }
}
