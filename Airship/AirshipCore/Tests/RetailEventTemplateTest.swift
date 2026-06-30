/* Copyright Airship and Contributors */

import Testing
@testable import AirshipCore

@Suite struct RetailEventTemplateTest {

    @Test
    func testBrowsed() {
        let event = CustomEvent(retailTemplate: .browsed)
        #expect("browsed" == event.eventName)
        #expect("retail" == event.templateType)

        let expectedProperties: [String: AirshipJSON] = ["ltv": false]
        #expect(expectedProperties == event.properties)
    }

    @Test
    func testAddedToCart() {
        let event = CustomEvent(retailTemplate: .addedToCart)
        #expect("added_to_cart" == event.eventName)
        #expect("retail" == event.templateType)

        let expectedProperties: [String: AirshipJSON] = ["ltv": false]
        #expect(expectedProperties == event.properties)
    }

    @Test
    func testStarred() {
        let event = CustomEvent(retailTemplate: .starred)
        #expect("starred_product" == event.eventName)
        #expect("retail" == event.templateType)

        let expectedProperties: [String: AirshipJSON] = ["ltv": false]
        #expect(expectedProperties == event.properties)
    }

    @Test
    func testPurchased() {
        let event = CustomEvent(retailTemplate: .purchased)
        #expect("purchased" == event.eventName)
        #expect("retail" == event.templateType)

        let expectedProperties: [String: AirshipJSON] = ["ltv": false]
        #expect(expectedProperties == event.properties)
    }

    @Test
    func testShared() {
        let event = CustomEvent(retailTemplate: .shared(source: "some source", medium: "some medium"))
        #expect("shared_product" == event.eventName)
        #expect("retail" == event.templateType)

        let expectedProperties: [String: AirshipJSON] = [
            "ltv": false,
            "source": "some source",
            "medium": "some medium"
        ]
        #expect(expectedProperties == event.properties)
    }

    @Test
    func testSharedEmptyDetails() {
        let event = CustomEvent(retailTemplate: .shared())
        #expect("shared_product" == event.eventName)
        #expect("retail" == event.templateType)

        let expectedProperties: [String: AirshipJSON] = ["ltv": false]
        #expect(expectedProperties == event.properties)
    }

    @Test
    func testWishlist() {
        let event = CustomEvent(retailTemplate: .wishlist(id: "some id", name: "some name"))
        #expect("wishlist" == event.eventName)
        #expect("retail" == event.templateType)

        let expectedProperties: [String: AirshipJSON] = [
            "ltv": false,
            "wishlist_id": "some id",
            "wishlist_name": "some name"
        ]
        #expect(expectedProperties == event.properties)
    }

    @Test
    func testWishlistEmptyDetails() {
        let event = CustomEvent(retailTemplate: .wishlist())
        #expect("wishlist" == event.eventName)
        #expect("retail" == event.templateType)

        let expectedProperties: [String: AirshipJSON] = ["ltv": false]
        #expect(expectedProperties == event.properties)
    }

    @Test
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
        #expect("wishlist" == event.eventName)
        #expect("retail" == event.templateType)

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

        #expect(expectedProperties == event.properties)
    }
}
