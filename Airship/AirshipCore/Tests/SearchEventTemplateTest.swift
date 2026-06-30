/* Copyright Airship and Contributors */

import Testing
@testable import AirshipCore

@Suite struct SearchEventTemplateTest {

    @Test
    func testSearch() {
        let event = CustomEvent(searchTemplate: .search)
        #expect("search" == event.eventName)
        #expect("search" == event.templateType)

        let expectedProperties: [String: AirshipJSON] = ["ltv": false]
        #expect(expectedProperties == event.properties)
    }

    @Test
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

        #expect("search" == event.eventName)
        #expect("search" == event.templateType)

        let expectedProperties: [String: AirshipJSON] = [
            "id": "some id",
            "category": "some category",
            "type": "some type",
            "ltv": true,
            "query": "some query",
            "total_results": 20

        ]
        #expect(expectedProperties == event.properties)
    }
}
