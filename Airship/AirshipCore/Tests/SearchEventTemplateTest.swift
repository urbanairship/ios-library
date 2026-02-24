/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class SearchEventTemplateTest: XCTestCase {

    func testSearch() {
        let event = CustomEvent(searchTemplate: .search)
        XCTAssertEqual("search", event.eventName)
        XCTAssertEqual("search", event.templateType)

        let expectedProperties: [String: AirshipJSON] = ["ltv": false]
        XCTAssertEqual(expectedProperties, event.properties)
    }

    func testProperties() {
        let event = CustomEvent(
            searchTemplate: .search,
            properties: .init(
                id: "some id",
                category: "some category",
                type: "some type",
                isLTV: true,
                query: "some query",
                totalResults: 20
            )
        )

        XCTAssertEqual("search", event.eventName)
        XCTAssertEqual("search", event.templateType)

        let expectedProperties: [String: AirshipJSON] = [
            "id": "some id",
            "category": "some category",
            "type": "some type",
            "ltv": true,
            "query": "some query",
            "total_results": 20

        ]
        XCTAssertEqual(expectedProperties, event.properties)
    }
}
