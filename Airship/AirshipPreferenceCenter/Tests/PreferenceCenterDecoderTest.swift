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
                 "name":"Notification Preferences"
              },
              "sections":[
                 {
                    "type":"labeled_section_break",
                    "id":"aae8dc8c-6232-4a7b-9203-ae88e4fea36a",
                    "conditions":[
                       {
                          "type":"notification_opt_in",
                          "when_status":"opt_out"
                       }
                    ]
                 },
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
                          },
                          "conditions":[
                             {
                                "type":"notification_opt_in",
                                "when_status":"opt_out"
                             }
                          ]
                       },
                       {
                          "type":"channel_subscription",
                          "id":"boring_news_id",
                          "subscription_id":"boring_news",
                          "display":{
                             "name":"Boring News",
                             "description":"It's pretty dull."
                          },
                          "conditions":[
                             {
                                "type":"notification_opt_in",
                                "when_status":"opt_in"
                             }
                          ]
                       },
                       {
                          "type":"contact_subscription",
                          "id":"very_boring_news_id",
                          "subscription_id":"very_boring_news",
                          "display":{
                             "name":"Very Boring News",
                             "description":"It's extremely dull."
                          },
                          "scopes":[
                             "email",
                             "web"
                          ]
                       },
                       {
                          "id":"some-uuid",
                          "type":"alert",
                          "display":{
                             "name":"Oh dang",
                             "description":"You need push notifications to be enabled.",
                             "icon":"https://whatever.example/icon.png"
                          },
                          "button":{
                             "text":"Opt In",
                             "content_description":"Opt in to push notifications",
                             "actions":{
                                "cool":"story"
                             }
                          }
                       },
                       {
                          "type":"contact_subscription_group",
                          "id":"some_group_thingy_id",
                          "subscription_id":"some_group_thingy_id",
                          "display":{
                             "name":"Something Something"
                          },
                          "components":[
                             {
                                "scopes":[
                                   "email",
                                   "sms"
                                ],
                                "display":{
                                   "name":"EMAIL & SMS"
                                }
                             },
                             {
                                "scopes":[
                                   "app"
                                ],
                                "display":{
                                   "name":"APP"
                                }
                             }
                          ]
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
        XCTAssertEqual(3, response.config.sections.count)
        
        let firstSection = response.config.sections[0] as! LabeledSectionBreakSection
        XCTAssertEqual(.labeledSectionBreak, firstSection.sectionType)
        XCTAssertEqual(SectionType.labeledSectionBreak.stringValue, firstSection.type)
        XCTAssertEqual("aae8dc8c-6232-4a7b-9203-ae88e4fea36a", firstSection.identifier)
        XCTAssertEqual(0, firstSection.items.count)
        XCTAssertEqual(1, firstSection.conditions?.count)
        
        let sectionCondition = firstSection.conditions?[0] as! NotificationOptInCondition
        XCTAssertEqual(.notificationOptIn, sectionCondition.conditionType)
        XCTAssertEqual(NotificationOptInCondition.OptInStatus.optedOut, sectionCondition.optInStatus)

        let secondSection = response.config.sections[1]
        XCTAssertEqual("section", secondSection.type)
        XCTAssertEqual("bbe8dc8c-6232-4a7b-9203-ae88e4fea36a", secondSection.identifier)
        XCTAssertEqual(1, secondSection.items.count)
        
        let thirdSection = response.config.sections[2]
        XCTAssertEqual("section", thirdSection.type)
        XCTAssertEqual("b8a192d0-d4cf-459b-b0d6-83a6cad7372e", thirdSection.identifier)
        XCTAssertEqual(5, thirdSection.items.count)
        
        let channelSubscriptionItem = thirdSection.items[1] as! ChannelSubscriptionItem
        XCTAssertEqual("channel_subscription", channelSubscriptionItem.type)
        XCTAssertEqual("boring_news_id", channelSubscriptionItem.identifier)
        XCTAssertEqual("boring_news", channelSubscriptionItem.subscriptionID)
        XCTAssertEqual("Boring News", channelSubscriptionItem.display?.title)
        XCTAssertEqual("It's pretty dull.", channelSubscriptionItem.display?.subtitle)
        XCTAssertEqual("It's pretty dull.", channelSubscriptionItem.display?.subtitle)

        let itemCondition = channelSubscriptionItem.conditions?[0] as! NotificationOptInCondition
        XCTAssertEqual(.notificationOptIn, itemCondition.conditionType)
        XCTAssertEqual(NotificationOptInCondition.OptInStatus.optedIn, itemCondition.optInStatus)
        
        let contactSubscriptionItem = thirdSection.items[2] as! ContactSubscriptionItem
        XCTAssertEqual(.contactSubscription, contactSubscriptionItem.itemType)
        XCTAssertEqual(ItemType.contactSubscription.stringValue, contactSubscriptionItem.type)
        XCTAssertEqual("very_boring_news_id", contactSubscriptionItem.identifier)
        XCTAssertEqual("very_boring_news", contactSubscriptionItem.subscriptionID)
        XCTAssertEqual("Very Boring News", contactSubscriptionItem.display?.title)
        XCTAssertEqual("It's extremely dull.", contactSubscriptionItem.display?.subtitle)
        XCTAssertEqual([.email, .web], contactSubscriptionItem.scopes.values)
    
        let alertItem = thirdSection.items[3] as! AlertItem
        XCTAssertEqual(.alert, alertItem.itemType)
        XCTAssertEqual(ItemType.alert.stringValue, alertItem.type)
        XCTAssertEqual("some-uuid", alertItem.identifier)
        XCTAssertEqual("Oh dang", alertItem.display?.title)
        XCTAssertEqual("You need push notifications to be enabled.", alertItem.display?.subtitle)
        XCTAssertEqual("https://whatever.example/icon.png", alertItem.display?.iconURL)
        XCTAssertEqual("Opt In", alertItem.button.text)
        XCTAssertEqual("Opt in to push notifications", alertItem.button.contentDescription)
        XCTAssertEqual(["cool": "story"] as! NSDictionary, alertItem.button.actions as! NSDictionary)

        let contactSubscriptionGroupItem = thirdSection.items[4] as! ContactSubscriptionGroupItem
        XCTAssertEqual(.contactSubscriptionGroup, contactSubscriptionGroupItem.itemType)
        XCTAssertEqual(ItemType.contactSubscriptionGroup.stringValue, contactSubscriptionGroupItem.type)
        XCTAssertEqual("some_group_thingy_id", contactSubscriptionGroupItem.identifier)
        XCTAssertEqual("some_group_thingy_id", contactSubscriptionGroupItem.subscriptionID)
        XCTAssertEqual("Something Something", contactSubscriptionGroupItem.display?.title)
        XCTAssertEqual(2, contactSubscriptionGroupItem.components.count)

        let fistComponent = contactSubscriptionGroupItem.components[0]
        XCTAssertEqual("EMAIL & SMS", fistComponent.display.title)
        XCTAssertEqual([.email, .sms], fistComponent.scopes.values)
        
        let secondComponent = contactSubscriptionGroupItem.components[1]
        XCTAssertEqual("APP", secondComponent.display.title)
        XCTAssertEqual([.app], secondComponent.scopes.values)
    }
}
