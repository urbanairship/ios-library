/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class RetailEventTemplateTest: XCTestCase {

    func testBrowsed() {
        let event = CustomEvent(retailTemplate: .browsed)
        XCTAssertEqual("browsed", event.eventName)
        XCTAssertEqual("retail", event.templateType)

        let expectedProperties: [String: AirshipJSON] = ["ltv": false]
        XCTAssertEqual(expectedProperties, event.properties)
    }

    func testAddedToCart() {
        let event = CustomEvent(retailTemplate: .addedToCart)
        XCTAssertEqual("added_to_cart", event.eventName)
        XCTAssertEqual("retail", event.templateType)

        let expectedProperties: [String: AirshipJSON] = ["ltv": false]
        XCTAssertEqual(expectedProperties, event.properties)
    }

    func testStarred() {
        let event = CustomEvent(retailTemplate: .starred)
        XCTAssertEqual("starred_product", event.eventName)
        XCTAssertEqual("retail", event.templateType)

        let expectedProperties: [String: AirshipJSON] = ["ltv": false]
        XCTAssertEqual(expectedProperties, event.properties)
    }

    func testPurchased() {
        let event = CustomEvent(retailTemplate: .purchased)
        XCTAssertEqual("purchased", event.eventName)
        XCTAssertEqual("retail", event.templateType)

        let expectedProperties: [String: AirshipJSON] = ["ltv": false]
        XCTAssertEqual(expectedProperties, event.properties)
    }

    func testShared() {
        let event = CustomEvent(retailTemplate: .shared(source: "some source", medium: "some medium"))
        XCTAssertEqual("shared_product", event.eventName)
        XCTAssertEqual("retail", event.templateType)

        let expectedProperties: [String: AirshipJSON] = [
            "ltv": false,
            "source": "some source",
            "medium": "some medium"
        ]
        XCTAssertEqual(expectedProperties, event.properties)
    }

    func testSharedEmptyDetails() {
        let event = CustomEvent(retailTemplate: .shared())
        XCTAssertEqual("shared_product", event.eventName)
        XCTAssertEqual("retail", event.templateType)

        let expectedProperties: [String: AirshipJSON] = ["ltv": false]
        XCTAssertEqual(expectedProperties, event.properties)
    }

    func testWishlist() {
        let event = CustomEvent(retailTemplate: .wishlist(id: "some id", name: "some name"))
        XCTAssertEqual("wishlist", event.eventName)
        XCTAssertEqual("retail", event.templateType)

        let expectedProperties: [String: AirshipJSON] = [
            "ltv": false,
            "wishlist_id": "some id",
            "wishlist_name": "some name"
        ]
        XCTAssertEqual(expectedProperties, event.properties)
    }

    func testWishlistEmptyDetails() {
        let event = CustomEvent(retailTemplate: .wishlist())
        XCTAssertEqual("wishlist", event.eventName)
        XCTAssertEqual("retail", event.templateType)

        let expectedProperties: [String: AirshipJSON] = ["ltv": false]
        XCTAssertEqual(expectedProperties, event.properties)
    }

    func testProperties() {
        let properties = CustomEvent.RetailProperties(
            id: "some id",
            category: "some category",
            type: "some type",
            eventDescription: "some description",
            isLTV: true,
            brand: "some brand",
            isNewItem: true,
            currency: "cred"
        )

        let event = CustomEvent(retailTemplate: .wishlist(), properties: properties)
        XCTAssertEqual("wishlist", event.eventName)
        XCTAssertEqual("retail", event.templateType)

        let expectedProperties: [String: AirshipJSON] = [
            "id": "some id",
            "category": "some category",
            "type": "some type",
            "description": "some description",
            "ltv": true,
            "brand": "some brand",
            "new_item": true,
            "currency": "cred",
        ]

        XCTAssertEqual(expectedProperties, event.properties)
    }
}
