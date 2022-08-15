/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipPreferenceCenter
import AirshipCore

class PreferenceCenterDecoderTest: XCTestCase {

    func testForm() throws {
        let form = """
        {
            "created": "2017-10-10T12:13:14.023",
            "last_updated": "2017-10-10T12:13:14.023",
            "form_id": "031de218-9fff-44d4-b348-de4b724bb924",
            "form": {
                "id": "preference_center_1",
                "display": {
                    "name": "Notification Preferences"
                },
                "options": {
                    "merge_channel_data_to_contact": true
                },
                "sections": [
                    {
                        "type": "labeled_section_break",
                        "id": "LabeledSectionBreak",
                        "conditions": [
                            {
                                "type": "notification_opt_in",
                                "when_status": "opt_out"
                            }
                        ],
                        "display": {
                            "name": "Labeled Section Break",
                        }
                    },
                    {
                        "type": "section",
                        "id": "common",
                        "display": {
                            "name": "Section Title",
                            "description": "Section Subtitle"
                        },
                        "items": [
                            {
                                "type": "channel_subscription",
                                "id": "ChannelSubscription",
                                "subscription_id": "ChannelSubscription",
                                "display": {
                                    "name": "Channel Subscription Title",
                                    "description": "Channel Subscription Subtitle"
                                }
                            },
                            {
                                "type": "contact_subscription",
                                "id": "ContactSubscription",
                                "subscription_id": "ContactSubscription",
                                "scopes": [
                                    "app",
                                    "web"
                                ],
                                "display": {
                                    "name": "Contact Subscription Title",
                                    "description": "Contact Subscription Subtitle"
                                }
                            },
                            {
                                "type": "contact_subscription_group",
                                "id": "ContactSubscriptionGroup",
                                "subscription_id": "ContactSubscriptionGroup",
                                "display": {
                                    "name": "Contact Subscription Group Title",
                                    "description": "Contact Subscription Group Subtitle"
                                },
                                "components": [
                                    {
                                        "scopes": [
                                            "web",
                                            "app"
                                        ],
                                        "display": {
                                            "name": "Web and App Component"
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

        let expected = PreferenceCenterConfig(
            identifier: "preference_center_1",
            sections: [
                .labeledSectionBreak(
                    PreferenceCenterConfig.LabeledSectionBreak(
                        identifier: "LabeledSectionBreak",
                        display: PreferenceCenterConfig.CommonDisplay(
                            title: "Labeled Section Break"
                        ),
                        conditions: [
                            .notificationOptIn(
                                PreferenceCenterConfig.NotificationOptInCondition(
                                    optInStatus: .optedOut
                                )
                            )
                        ]
                    )
                ),
                .common(
                    PreferenceCenterConfig.CommonSection(
                        identifier: "common",
                        items: [
                            .channelSubscription(
                                PreferenceCenterConfig.ChannelSubscription(
                                    identifier: "ChannelSubscription",
                                    subscriptionID: "ChannelSubscription",
                                    display: PreferenceCenterConfig.CommonDisplay(
                                        title: "Channel Subscription Title",
                                        subtitle: "Channel Subscription Subtitle"
                                    )
                                )
                            ),
                            .contactSubscription(
                                PreferenceCenterConfig.ContactSubscription(
                                    identifier: "ContactSubscription",
                                    subscriptionID: "ContactSubscription",
                                    scopes: [.app, .web],
                                    display: PreferenceCenterConfig.CommonDisplay(
                                        title: "Contact Subscription Title",
                                        subtitle: "Contact Subscription Subtitle"
                                    )
                                )
                            ),
                            .contactSubscriptionGroup(
                                PreferenceCenterConfig.ContactSubscriptionGroup(
                                    identifier: "ContactSubscriptionGroup",
                                    subscriptionID: "ContactSubscriptionGroup",
                                    components: [
                                        PreferenceCenterConfig.ContactSubscriptionGroup.Component(
                                            scopes: [.web, .app],
                                            display: PreferenceCenterConfig.CommonDisplay(
                                                title: "Web and App Component"
                                            )
                                        )
                                    ],
                                    display: PreferenceCenterConfig.CommonDisplay(
                                        title: "Contact Subscription Group Title",
                                        subtitle: "Contact Subscription Group Subtitle"
                                    )
                                )
                            )
                        ],
                        display: PreferenceCenterConfig.CommonDisplay(
                            title: "Section Title",
                            subtitle: "Section Subtitle"
                        )
                    )
                )
            ],
            display: PreferenceCenterConfig.CommonDisplay(
                title: "Notification Preferences"
            ),
            options: PreferenceCenterConfig.Options(
                mergeChannelDataToContact: true
            )
        )

        let response = try! PreferenceCenterDecoder.decodeConfig(data: form.data(using: .utf8)!)
        XCTAssertEqual(expected, response.config)
    }
}
