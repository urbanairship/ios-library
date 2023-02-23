/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class ContactAPIClientTest: XCTestCase {

    var config: RuntimeConfig!
    var localeManager: AirshipLocaleManager!
    var session: TestRequestSession!
    var contactAPIClient: ContactAPIClient!

    override func setUpWithError() throws {
        let airshipConfig = AirshipConfig()
        airshipConfig.requireInitialRemoteConfigEnabled = false
        self.config = RuntimeConfig(
            config: airshipConfig,
            dataStore: PreferenceDataStore(appKey: UUID().uuidString)
        )
        self.localeManager = AirshipLocaleManager(
            dataStore: PreferenceDataStore(appKey: config.appKey)
        )
        self.session = TestRequestSession.init()
        self.session.response = HTTPURLResponse(
            url: URL(string: "https://contacts_test")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: [String: String]()
        )

        self.contactAPIClient = ContactAPIClient.init(
            config: self.config,
            session: self.session
        )
    }

    func testIdentify() async throws {
        self.session.data = """
            {
                "contact_id": "56779"
            }
            """
            .data(using: .utf8)

        let response = try await contactAPIClient.identify(
            channelID: "test_channel",
            namedUserID: "contact",
            contactID: nil
        )
        
        XCTAssertTrue(response.isSuccess)
        XCTAssertNotNil(response.result!.contactID)
        XCTAssertNotNil(response.result!.isAnonymous)
    }

    func testResolve() async throws {
        self.session.data = """
            {
                "contact_id": "56779",
                "is_anonymous": true
            }
            """
            .data(using: .utf8)

        let response = try await contactAPIClient.resolve(channelID: "test_channel")
        
        XCTAssertTrue(response.isSuccess)
        XCTAssertNotNil(response.result!.contactID)
    }

    func testReset() async throws {
        self.session.data = """
            {
                "contact_id": "56779",
            }
            """
            .data(using: .utf8)

        let response = try await contactAPIClient.reset(channelID: "test_channel")
        
        XCTAssertTrue(response.isSuccess)
        XCTAssertNotNil(response.result!.contactID)
    }

    func testRegisterEmail() async throws {
        self.session.data = """
            {
                "channel_id": "some-channel",
            }
            """
            .data(using: .utf8)
        let date = Date()
        let response = try await contactAPIClient.registerEmail(
            identifier: "some-contact-id",
            address: "ua@airship.com",
            options: EmailRegistrationOptions.options(
                transactionalOptedIn: date,
                properties: ["interests": "newsletter"],
                doubleOptIn: true
            )
        )

        XCTAssertTrue(response.isSuccess)
        XCTAssertEqual("some-channel", response.result!.channelID)
        XCTAssertEqual(.email, response.result!.channelType)
        
        let previousRequest = self.session.previousRequest!
        XCTAssertNotNil(previousRequest)
        XCTAssertEqual(
            "https://device-api.urbanairship.com/api/channels/restricted/email",
            previousRequest.url!.absoluteString
        )

        let previousBody = try JSONSerialization.jsonObject(
            with: previousRequest.body!,
            options: []
        )
        let currentLocale = self.localeManager.currentLocale

        let formatter = AirshipUtils.isoDateFormatterUTCWithDelimiter()
        let previousExpectedBody: Any = [
            "channel": [
                "type": "email",
                "address": "ua@airship.com",
                "timezone": TimeZone.current.identifier,
                "locale_country": currentLocale.regionCode ?? "",
                "locale_language": currentLocale.languageCode ?? "",
                "transactional_opted_in": formatter.string(from: date),
            ],
            "opt_in_mode": "double",
            "properties": [
                "interests": "newsletter"
            ],
        ]
        XCTAssertEqual(
            previousBody as! NSDictionary,
            previousExpectedBody as! NSDictionary
        )

        let lastRequest = self.session.lastRequest!
        XCTAssertEqual(
            "https://device-api.urbanairship.com/api/contacts/some-contact-id",
            lastRequest.url!.absoluteString
        )

        let lastBody = try JSONSerialization.jsonObject(
            with: lastRequest.body!,
            options: []
        )
        let lastExpectedBody: Any = [
            "associate": [
                [
                    "device_type": "email",
                    "channel_id": "some-channel",
                ]
            ]
        ]
        XCTAssertEqual(
            lastBody as! NSDictionary,
            lastExpectedBody as! NSDictionary
        )
    }

    func testRegisterSMS() async throws {
        self.session.data = """
            {
                "channel_id": "some-channel",
            }
            """
            .data(using: .utf8)

        let response = try await contactAPIClient.registerSMS(
            identifier: "some-contact-id",
            msisdn: "15035556789",
            options: SMSRegistrationOptions.optIn(senderID: "28855")
        )
      
        XCTAssertTrue(response.isSuccess)
        XCTAssertEqual("some-channel", response.result!.channelID)
        XCTAssertEqual(.sms, response.result!.channelType)
        
        let previousRequest = self.session.previousRequest!
        XCTAssertNotNil(previousRequest)
        XCTAssertEqual(
            "https://device-api.urbanairship.com/api/channels/restricted/sms",
            previousRequest.url!.absoluteString
        )

        let previousBody = try JSONSerialization.jsonObject(
            with: previousRequest.body!,
            options: []
        )
        let currentLocale = self.localeManager.currentLocale
        let previousExpectedBody: Any = [
            "msisdn": "15035556789",
            "sender": "28855",
            "timezone": TimeZone.current.identifier,
            "locale_country": currentLocale.regionCode ?? "",
            "locale_language": currentLocale.languageCode ?? "",
        ]
        XCTAssertEqual(
            previousBody as! NSDictionary,
            previousExpectedBody as! NSDictionary
        )

        let lastRequest = self.session.lastRequest!
        XCTAssertEqual(
            "https://device-api.urbanairship.com/api/contacts/some-contact-id",
            lastRequest.url!.absoluteString
        )

        let lastBody = try JSONSerialization.jsonObject(
            with: lastRequest.body!,
            options: []
        )
        let lastExpectedBody: Any = [
            "associate": [
                [
                    "device_type": "sms",
                    "channel_id": "some-channel",
                ]
            ]
        ]
        XCTAssertEqual(
            lastBody as! NSDictionary,
            lastExpectedBody as! NSDictionary
        )
    }

    func testRegisterOpen() async throws {
        self.session.data = """
            {
                "channel_id": "some-channel",
            }
            """
            .data(using: .utf8)

        let response = try await contactAPIClient.registerOpen(
            identifier: "some-contact-id",
            address: "open_address",
            options: OpenRegistrationOptions.optIn(
                platformName: "my_platform",
                identifiers: ["model": "4", "category": "1"]
            )
        )
        
        XCTAssertTrue(response.isSuccess)
        XCTAssertEqual("some-channel", response.result!.channelID)
        XCTAssertEqual(.open, response.result!.channelType)

        let previousRequest = self.session.previousRequest!
        XCTAssertNotNil(previousRequest)
        XCTAssertEqual(
            "https://device-api.urbanairship.com/api/channels/restricted/open",
            previousRequest.url!.absoluteString
        )

        let previousBody = try JSONSerialization.jsonObject(
            with: previousRequest.body!,
            options: []
        )
        let currentLocale = self.localeManager.currentLocale
        let previousExpectedBody: Any = [
            "channel": [
                "type": "open",
                "address": "open_address",
                "timezone": TimeZone.current.identifier,
                "locale_country": currentLocale.regionCode ?? "",
                "locale_language": currentLocale.languageCode ?? "",
                "opt_in": true,
                "open": [
                    "open_platform_name": "my_platform",
                    "identifiers": [
                        "model": "4",
                        "category": "1",
                    ],
                ],
            ]
        ]
        XCTAssertEqual(
            previousBody as! NSDictionary,
            previousExpectedBody as! NSDictionary
        )

        let lastRequest = self.session.lastRequest!
        XCTAssertEqual(
            "https://device-api.urbanairship.com/api/contacts/some-contact-id",
            lastRequest.url!.absoluteString
        )

        let lastBody = try JSONSerialization.jsonObject(
            with: lastRequest.body!,
            options: []
        )
        let lastExpectedBody: Any = [
            "associate": [
                [
                    "device_type": "open",
                    "channel_id": "some-channel",
                ]
            ]
        ]
        XCTAssertEqual(
            lastBody as! NSDictionary,
            lastExpectedBody as! NSDictionary
        )
    }

    func testAssociateChannel() async throws {
        let response = try await contactAPIClient.associateChannel(
            identifier: "some-contact-id",
            channelID: "some-channel",
            channelType: .sms
        )
        
        XCTAssertTrue(response.isSuccess)
        XCTAssertEqual("some-channel", response.result!.channelID)
        XCTAssertEqual(.sms, response.result!.channelType)

        let request = self.session.lastRequest!
        XCTAssertEqual(
            "https://device-api.urbanairship.com/api/contacts/some-contact-id",
            request.url!.absoluteString
        )

        let body = try JSONSerialization.jsonObject(
            with: request.body!,
            options: []
        )
        let expectedBody: Any = [
            "associate": [
                [
                    "device_type": "sms",
                    "channel_id": "some-channel",
                ]
            ]
        ]
        XCTAssertEqual(body as! NSDictionary, expectedBody as! NSDictionary)
    }

    func testUpdate() async throws {
        let tagUpdates = [
            TagGroupUpdate(group: "tag-set", tags: [], type: .set),
            TagGroupUpdate(group: "tag-add", tags: ["add tag"], type: .add),
            TagGroupUpdate(
                group: "tag-other-add",
                tags: ["other tag"],
                type: .add
            ),
            TagGroupUpdate(
                group: "tag-remove",
                tags: ["remove tag"],
                type: .remove
            ),
        ]

        let date = Date()
        let attributeUpdates = [
            AttributeUpdate.set(
                attribute: "some-string",
                value: "Hello",
                date: date
            ),
            AttributeUpdate.set(
                attribute: "some-number",
                value: 32.0,
                date: date
            ),
            AttributeUpdate.remove(attribute: "some-remove", date: date),
        ]

        let listUpdates = [
            ScopedSubscriptionListUpdate(
                listId: "bar",
                type: .subscribe,
                scope: .web,
                date: date
            ),
            ScopedSubscriptionListUpdate(
                listId: "foo",
                type: .unsubscribe,
                scope: .app,
                date: date
            ),
        ]

        let response = try await contactAPIClient.update(
            identifier: "some-contact-id",
            tagGroupUpdates: tagUpdates,
            attributeUpdates: attributeUpdates,
            subscriptionListUpdates: listUpdates
        )

        XCTAssertTrue(response.isSuccess)
        
        let request = self.session.lastRequest!
        XCTAssertEqual(
            "https://device-api.urbanairship.com/api/contacts/some-contact-id",
            request.url!.absoluteString
        )

        let body = try JSONSerialization.jsonObject(
            with: request.body!,
            options: []
        )
        let formattedDate = AirshipUtils.isoDateFormatterUTCWithDelimiter()
            .string(
                from: date
            )
        let expectedBody: Any = [
            "attributes": [
                [
                    "action": "set",
                    "key": "some-string",
                    "timestamp": formattedDate,
                    "value": "Hello",
                ],
                [
                    "action": "set",
                    "key": "some-number",
                    "timestamp": formattedDate,
                    "value": 32,
                ],
                [
                    "action": "remove",
                    "key": "some-remove",
                    "timestamp": formattedDate,
                ],
            ],
            "tags": [
                "add": [
                    "tag-add": [
                        "add tag"
                    ],
                    "tag-other-add": [
                        "other tag"
                    ],
                ],
                "remove": [
                    "tag-remove": [
                        "remove tag"
                    ]
                ],
                "set": [
                    "tag-set": []
                ],
            ],
            "subscription_lists": [
                [
                    "action": "subscribe",
                    "list_id": "bar",
                    "scope": "web",
                    "timestamp": formattedDate,
                ],
                [
                    "action": "unsubscribe",
                    "list_id": "foo",
                    "scope": "app",
                    "timestamp": formattedDate,
                ],
            ],
        ]

        XCTAssertEqual(body as! NSDictionary, expectedBody as! NSDictionary)
    }

    func testUpdateMixValidInvalidAttributes() async throws {
        let date = Date()
        let attributeUpdates = [
            AttributeUpdate(
                attribute: "some-string",
                type: .set,
                value: nil,
                date: date
            ),
            AttributeUpdate.set(
                attribute: "some-string",
                value: "Hello",
                date: date
            ),
        ]

        let response = try await contactAPIClient.update(
            identifier: "some-contact-id",
            tagGroupUpdates: [],
            attributeUpdates: attributeUpdates,
            subscriptionListUpdates: nil
        )
        
        XCTAssertTrue(response.isSuccess)

        let request = self.session.lastRequest!
        XCTAssertEqual(
            "https://device-api.urbanairship.com/api/contacts/some-contact-id",
            request.url!.absoluteString
        )

        let body = try JSONSerialization.jsonObject(
            with: request.body!,
            options: []
        )
        let formattedDate = AirshipUtils.isoDateFormatterUTCWithDelimiter()
            .string(
                from: date
            )
        let expectedBody: Any = [
            "attributes": [
                [
                    "action": "set",
                    "key": "some-string",
                    "timestamp": formattedDate,
                    "value": "Hello",
                ]
            ]
        ]

        XCTAssertEqual(body as! NSDictionary, expectedBody as! NSDictionary)
    }

    func testGetContactLists() async throws {
        let responseBody = """
            {
               "ok" : true,
               "subscription_lists": [
                  {
                     "list_ids": ["example_listId-1", "example_listId-3"],
                      "scope": "email"
                  },
                  {
                     "list_ids": ["example_listId-2", "example_listId-4"],
                     "scope": "app"
                  },
                  {
                     "list_ids": ["example_listId-2"],
                     "scope": "web"
                  }
               ],
            }
            """

        self.session.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: [String: String]()
        )
        self.session.data = responseBody.data(using: .utf8)

        let expected: [String: [ChannelScope]] = [
            "example_listId-1": [.email],
            "example_listId-2": [.app, .web],
            "example_listId-3": [.email],
            "example_listId-4": [.app],
        ]

        let response = try await self.contactAPIClient.fetchSubscriptionLists("some-contact")
        XCTAssertTrue(response.isSuccess)
    
        XCTAssertEqual(expected, response.result!)
       
        XCTAssertEqual("GET", self.session.lastRequest?.method)
        XCTAssertEqual(
            "https://device-api.urbanairship.com/api/subscription_lists/contacts/some-contact",
            self.session.lastRequest?.url?.absoluteString
        )
    }

    func testGetContactListParseError() async throws {
        let responseBody = "What?"

        self.session.data = responseBody.data(using: .utf8)
        
        self.session.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: [String: String]()
        )

        do {
            _ = try await self.contactAPIClient.fetchSubscriptionLists("some-contact")
            XCTFail()
        }
        catch {
    
        }
    }

    func testGetContactListError() async throws {
        let sessionError = AirshipErrors.error("error!")
        self.session.error = sessionError

        do {
            _ = try await self.contactAPIClient.fetchSubscriptionLists("some-contact")
            XCTFail()
        }
        catch {

        }
    }
}
