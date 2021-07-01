/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipPreferenceCenter
import AirshipCore

class PreferenceCenterDecoderTest: XCTestCase {
        
    func testForm() throws {
        let form = """
        {
           "created":"2017-10-10T12:13:14.023",
           "last_updated":"2017-10-10T12:13:14.023",
           "form_id":"031de218-9fff-44d4-b348-de4b724bb924",
           "form":{
              "id":"preference_center_1",
              "display":{
                 "name":"Notification Preferences",
              },
              "sections":[
                 {
                    "type":"section",
                    "id":"bbe8dc8c-6232-4a7b-9203-ae88e4fea36a",
                    "items":[
                       {
                          "type":"channel_subscription",
                          "id":"shipping_notifications",
                          "subscription_id":"shipping_notifications",
                          "display":{
                             "name":"Shipping Notifications"
                          }
                       }
                    ]
                 },
                 {
                    "type":"section",
                    "id":"b8a192d0-d4cf-459b-b0d6-83a6cad7372e",
                    "display":{
                       "name":"News"
                    },
                    "items":[
                       {
                          "type":"channel_subscription",
                          "id":"cool_news",
                          "subscription_id":"cool_news",
                          "display":{
                             "name":"Cool News",
                             "description":"Only the coolest news."
                          }
                       },
                       {
                          "type":"channel_subscription",
                          "id":"boring_news_id",
                          "subscription_id":"boring_news",
                          "display":{
                             "name":"Boring News",
                             "description":"It's pretty dull."
                          }
                       }
                    ]
                 }
              ]
           }
        }
        """

        let response = try! PreferenceCenterDecoder.decodeConfig(data: form.data(using: .utf8)!)
        XCTAssertEqual("preference_center_1", response.config.identifier)
        XCTAssertEqual("Notification Preferences", response.config.display?.title)
        XCTAssertEqual(2, response.config.sections.count)
        
        let firstSection = response.config.sections[0]
        XCTAssertEqual("section", firstSection.type)
        XCTAssertEqual("bbe8dc8c-6232-4a7b-9203-ae88e4fea36a", firstSection.identifier)
        XCTAssertEqual(1, firstSection.items.count)
        
        let secondSection = response.config.sections[1]
        XCTAssertEqual("section", secondSection.type)
        XCTAssertEqual("b8a192d0-d4cf-459b-b0d6-83a6cad7372e", secondSection.identifier)
        XCTAssertEqual(2, secondSection.items.count)
        
        let boringNewsItem = secondSection.items[1] as! ChannelSubscriptionItem
        XCTAssertEqual("channel_subscription", boringNewsItem.type)
        XCTAssertEqual("boring_news_id", boringNewsItem.identifier)
        XCTAssertEqual("boring_news", boringNewsItem.subscriptionID)
        XCTAssertEqual("Boring News", boringNewsItem.display?.title)
        XCTAssertEqual("It's pretty dull.", boringNewsItem.display?.subtitle)
    }

}
