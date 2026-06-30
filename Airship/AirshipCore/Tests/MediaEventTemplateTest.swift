/* Copyright Airship and Contributors */

import Testing
@testable import AirshipCore
import Foundation

@Suite struct MediaEventTemplateTest {

    @Test
    func testBrowsed() {
        let event = CustomEvent(mediaTemplate: .browsed)
        #expect("browsed_content" == event.eventName)
        #expect("media" == event.templateType)

        let expectedProperties: [String: AirshipJSON] = ["ltv": false]
        #expect(expectedProperties == event.properties)
    }

    @Test
    func testConsumed() {
        let event = CustomEvent(mediaTemplate: .consumed)
        #expect("consumed_content" == event.eventName)
        #expect("media" == event.templateType)

        let expectedProperties: [String: AirshipJSON] = ["ltv": false]
        #expect(expectedProperties == event.properties)
    }

    @Test
    func testShared() {
        let event = CustomEvent(mediaTemplate: .shared(source: "some source", medium: "some medium"))
        #expect("shared_content" == event.eventName)
        #expect("media" == event.templateType)

        let expectedProperties: [String: AirshipJSON] = [
            "ltv": false,
            "source": "some source",
            "medium": "some medium"
        ]
        #expect(expectedProperties == event.properties)
    }

    @Test
    func testSharedEmptyDetails() {
        let event = CustomEvent(mediaTemplate: .shared())
        #expect("shared_content" == event.eventName)
        #expect("media" == event.templateType)

        let expectedProperties: [String: AirshipJSON] = ["ltv": false]
        #expect(expectedProperties == event.properties)
    }

    @Test
    func testStarred() {
        let event = CustomEvent(mediaTemplate: .starred)
        #expect("starred_content" == event.eventName)
        #expect("media" == event.templateType)

        let expectedProperties: [String: AirshipJSON] = ["ltv": false]
        #expect(expectedProperties == event.properties)
    }

    @Test
    func testProperties() {
        let date = Date.now
        let properties = CustomEvent.MediaProperties(
            id: "some id",
            category: "some category",
            type: "some type",
            eventDescription: "some description",
            isLTV: true,
            author: "some author",
            publishedDate: date,
            isFeature: true
        )

        let event = CustomEvent(
            mediaTemplate: .shared(source: "some source", medium: "some medium"),
            properties: properties
        )
        #expect("shared_content" == event.eventName)
        #expect("media" == event.templateType)

        let expectedProperties: [String: AirshipJSON] = [
            "id": "some id",
            "category": "some category",
            "type": "some type",
            "description": "some description",
            "ltv": true,
            "author": "some author",
            "published_date": try! AirshipJSON.wrap(date, encoder: CustomEvent.defaultEncoder()),
            "feature": true,
            "source": "some source",
            "medium": "some medium"
        ]

        #expect(expectedProperties == event.properties)
    }
}
