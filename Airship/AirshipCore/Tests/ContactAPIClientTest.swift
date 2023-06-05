/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class ContactAPIClientTest: XCTestCase {

    private let session: TestAirshipRequestSession = TestAirshipRequestSession()
    private var contactAPIClient: ContactAPIClient!
    private var config: RuntimeConfig!
    private let currentLocale = Locale(identifier: "fr-CA")

    override func setUpWithError() throws {
        let airshipConfig = AirshipConfig()
        airshipConfig.deviceAPIURL = "https://example.com"
        airshipConfig.requireInitialRemoteConfigEnabled = false
        self.config = RuntimeConfig(
            config: airshipConfig,
            dataStore: PreferenceDataStore(appKey: UUID().uuidString)
        )
        self.session.response = HTTPURLResponse(
            url: URL(string: "https://contacts_test")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: [String: String]()
        )

        self.contactAPIClient = ContactAPIClient(
            config: self.config,
            session: self.session
        )
    }

    func testIdentify() async throws {
        self.session.data = """
            {
              "ok": true,
              "contact": {
                "contact_id": "1a32e8c7-5a73-47c0-9716-99fd3d41924b",
                "is_anonymous": true,
                "channel_association_timestamp": "2022-12-29T10:15:30.00"
              },
              "token": "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJLSHVNTE15RmVmYjdoeXR3WkV5VTF4IiwiaWF0IjoxNjAyMDY4NDIxLCJleHAiOjE2MDIwNjg0MjEsInN1YiI6InVMa2hSaktBYzVXQW1SdTFPTFZSVncifQ.kJPu3enbLJMX10xEtzlxxeum66R2ZWLs02OSVPhjomQ",
              "token_expires_in": 3600000
            }
            """
            .data(using: .utf8)

        let response = try await contactAPIClient.identify(
            channelID: "test_channel",
            namedUserID: "my-named-user",
            contactID: nil,
            possiblyOrphanedContactID: "1a32e8c7-5a73-47c0-9716-99fd3d41924c"
        )

        let expected = ContactIdentifyResult(
            contact: ContactIdentifyResult.ContactInfo(
                channelAssociatedDate: AirshipUtils.parseISO8601Date(from: "2022-12-29T10:15:30.00")!,
                contactID: "1a32e8c7-5a73-47c0-9716-99fd3d41924b",
                isAnonymous: true
            ),
            token: "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJLSHVNTE15RmVmYjdoeXR3WkV5VTF4IiwiaWF0IjoxNjAyMDY4NDIxLCJleHAiOjE2MDIwNjg0MjEsInN1YiI6InVMa2hSaktBYzVXQW1SdTFPTFZSVncifQ.kJPu3enbLJMX10xEtzlxxeum66R2ZWLs02OSVPhjomQ",
            tokenExpiresInMilliseconds: 3600000
        )

        XCTAssertTrue(response.isSuccess)
        XCTAssertEqual(response.result!, expected)

        let request = session.lastRequest!

        let requestBody = try AirshipJSON.from(data: request.body).unWrap() as! [String: AnyHashable]
        let expectedBody = [
            "device_info": [
                "device_type": "ios"
            ],
            "action": [
                "type": "identify",
                "named_user_id": "my-named-user",
                "possibly_orphaned_contact_id": "1a32e8c7-5a73-47c0-9716-99fd3d41924c"
              ]
            ]

        XCTAssertEqual(expectedBody, requestBody)
        XCTAssertEqual(request.url?.absoluteString, "https://example.com/api/contacts/identify/v2")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.auth, .generatedChannelToken(identifier: "test_channel"))
        XCTAssertEqual(
            request.headers,
            [
                "Content-Type": "application/json",
                "Accept": "application/vnd.urbanairship+json; version=3;",
            ]
        )
    }

    func testResolve() async throws {
        self.session.data = """
            {
              "ok": true,
              "contact": {
                "contact_id": "1a32e8c7-5a73-47c0-9716-99fd3d41924b",
                "is_anonymous": true,
                "channel_association_timestamp": "2022-12-29T10:15:30.00"
              },
              "token": "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJLSHVNTE15RmVmYjdoeXR3WkV5VTF4IiwiaWF0IjoxNjAyMDY4NDIxLCJleHAiOjE2MDIwNjg0MjEsInN1YiI6InVMa2hSaktBYzVXQW1SdTFPTFZSVncifQ.kJPu3enbLJMX10xEtzlxxeum66R2ZWLs02OSVPhjomQ",
              "token_expires_in": 3600000
            }
            """
            .data(using: .utf8)

        let response = try await contactAPIClient.resolve(
            channelID: "test_channel",
            contactID: "some contact id",
            possiblyOrphanedContactID: "1a32e8c7-5a73-47c0-9716-99fd3d41924c"
        )

        let expected = ContactIdentifyResult(
            contact: ContactIdentifyResult.ContactInfo(
                channelAssociatedDate: AirshipUtils.parseISO8601Date(from: "2022-12-29T10:15:30.00")!,
                contactID: "1a32e8c7-5a73-47c0-9716-99fd3d41924b",
                isAnonymous: true
            ),
            token: "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJLSHVNTE15RmVmYjdoeXR3WkV5VTF4IiwiaWF0IjoxNjAyMDY4NDIxLCJleHAiOjE2MDIwNjg0MjEsInN1YiI6InVMa2hSaktBYzVXQW1SdTFPTFZSVncifQ.kJPu3enbLJMX10xEtzlxxeum66R2ZWLs02OSVPhjomQ",
            tokenExpiresInMilliseconds: 3600000
        )

        XCTAssertTrue(response.isSuccess)
        XCTAssertEqual(response.result!, expected)

        let request = session.lastRequest!

        let requestBody = try AirshipJSON.from(data: request.body).unWrap() as! [String: AnyHashable]
        let expectedBody = [
            "device_info": [
                "device_type": "ios"
            ],
            "action": [
                "type": "resolve",
                "contact_id": "some contact id",
                "possibly_orphaned_contact_id": "1a32e8c7-5a73-47c0-9716-99fd3d41924c"
              ]
            ]

        XCTAssertEqual(expectedBody, requestBody)
        XCTAssertEqual(request.url?.absoluteString, "https://example.com/api/contacts/identify/v2")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.auth, .generatedChannelToken(identifier: "test_channel"))
        XCTAssertEqual(
            request.headers,
            [
                "Content-Type": "application/json",
                "Accept": "application/vnd.urbanairship+json; version=3;",
            ]
        )
    }

    func testReset() async throws {
        self.session.data = """
            {
              "ok": true,
              "contact": {
                "contact_id": "1a32e8c7-5a73-47c0-9716-99fd3d41924b",
                "is_anonymous": true,
                "channel_association_timestamp": "2022-12-29T10:15:30.00"
              },
              "token": "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJLSHVNTE15RmVmYjdoeXR3WkV5VTF4IiwiaWF0IjoxNjAyMDY4NDIxLCJleHAiOjE2MDIwNjg0MjEsInN1YiI6InVMa2hSaktBYzVXQW1SdTFPTFZSVncifQ.kJPu3enbLJMX10xEtzlxxeum66R2ZWLs02OSVPhjomQ",
              "token_expires_in": 3600000
            }
            """
            .data(using: .utf8)

        let response = try await contactAPIClient.reset(
            channelID: "test_channel",
            possiblyOrphanedContactID: "1a32e8c7-5a73-47c0-9716-99fd3d41924c"
        )

        let expected = ContactIdentifyResult(
            contact: ContactIdentifyResult.ContactInfo(
                channelAssociatedDate: AirshipUtils.parseISO8601Date(from: "2022-12-29T10:15:30.00")!,
                contactID: "1a32e8c7-5a73-47c0-9716-99fd3d41924b",
                isAnonymous: true
            ),
            token: "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJLSHVNTE15RmVmYjdoeXR3WkV5VTF4IiwiaWF0IjoxNjAyMDY4NDIxLCJleHAiOjE2MDIwNjg0MjEsInN1YiI6InVMa2hSaktBYzVXQW1SdTFPTFZSVncifQ.kJPu3enbLJMX10xEtzlxxeum66R2ZWLs02OSVPhjomQ",
            tokenExpiresInMilliseconds: 3600000
        )

        XCTAssertTrue(response.isSuccess)
        XCTAssertEqual(response.result!, expected)

        let request = session.lastRequest!

        let requestBody = try AirshipJSON.from(data: request.body).unWrap() as! [String: AnyHashable]
        let expectedBody = [
            "device_info": [
                "device_type": "ios"
            ],
            "action": [
                "type": "reset",
                "possibly_orphaned_contact_id": "1a32e8c7-5a73-47c0-9716-99fd3d41924c"
              ]
            ]

        XCTAssertEqual(expectedBody, requestBody)
        XCTAssertEqual(request.url?.absoluteString, "https://example.com/api/contacts/identify/v2")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.auth, .generatedChannelToken(identifier: "test_channel"))
        XCTAssertEqual(
            request.headers,
            [
                "Content-Type": "application/json",
                "Accept": "application/vnd.urbanairship+json; version=3;",
            ]
        )
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
            contactID: "some-contact-id",
            address: "ua@airship.com",
            options: EmailRegistrationOptions.options(
                transactionalOptedIn: date,
                properties: ["interests": "newsletter"],
                doubleOptIn: true
            ),
            locale: currentLocale
        )

        XCTAssertTrue(response.isSuccess)
        XCTAssertEqual("some-channel", response.result!.channelID)
        XCTAssertEqual(.email, response.result!.channelType)

        let previousRequest = self.session.previousRequest!
        XCTAssertNotNil(previousRequest)
        XCTAssertEqual(
            "https://example.com/api/channels/restricted/email",
            previousRequest.url!.absoluteString
        )

        let previousBody = try JSONSerialization.jsonObject(
            with: previousRequest.body!,
            options: []
        ) as! [String : AnyHashable]

        let formatter = AirshipUtils.isoDateFormatterUTCWithDelimiter()
        let previousExpectedBody: [String : AnyHashable] = [
            "channel": [
                "type": "email",
                "address": "ua@airship.com",
                "timezone": TimeZone.current.identifier,
                "locale_country": "CA",
                "locale_language": "fr",
                "transactional_opted_in": formatter.string(from: date),
            ],
            "opt_in_mode": "double",
            "properties": [
                "interests": "newsletter"
            ],
        ]

        XCTAssertEqual(
            previousBody,
            previousExpectedBody
        )

        let lastRequest = self.session.lastRequest!
        XCTAssertEqual(
            "https://example.com/api/contacts/some-contact-id",
            lastRequest.url!.absoluteString
        )

        let lastBody = try JSONSerialization.jsonObject(
            with: lastRequest.body!,
            options: []
        ) as! [String : AnyHashable]

        let lastExpectedBody:[String : AnyHashable] = [
            "associate": [
                [
                    "device_type": "email",
                    "channel_id": "some-channel",
                ]
            ]
        ]
        XCTAssertEqual(
            lastBody,
            lastExpectedBody
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
            contactID: "some-contact-id",
            msisdn: "15035556789",
            options: SMSRegistrationOptions.optIn(senderID: "28855"),
            locale: currentLocale
        )

        XCTAssertTrue(response.isSuccess)
        XCTAssertEqual("some-channel", response.result!.channelID)
        XCTAssertEqual(.sms, response.result!.channelType)

        let previousRequest = self.session.previousRequest!
        XCTAssertNotNil(previousRequest)
        XCTAssertEqual(
            "https://example.com/api/channels/restricted/sms",
            previousRequest.url!.absoluteString
        )

        let previousBody = try JSONSerialization.jsonObject(
            with: previousRequest.body!,
            options: []
        )
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
            "https://example.com/api/contacts/some-contact-id",
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
            contactID: "some-contact-id",
            address: "open_address",
            options: OpenRegistrationOptions.optIn(
                platformName: "my_platform",
                identifiers: ["model": "4", "category": "1"]
            ),
            locale: currentLocale
        )

        XCTAssertTrue(response.isSuccess)
        XCTAssertEqual("some-channel", response.result!.channelID)
        XCTAssertEqual(.open, response.result!.channelType)

        let previousRequest = self.session.previousRequest!
        XCTAssertNotNil(previousRequest)
        XCTAssertEqual(
            "https://example.com/api/channels/restricted/open",
            previousRequest.url!.absoluteString
        )

        let previousBody = try JSONSerialization.jsonObject(
            with: previousRequest.body!,
            options: []
        )
        let previousExpectedBody: [String: Any] = [
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
                ] as [String : Any],
            ] as [String : Any]
        ]
        XCTAssertEqual(
            previousBody as! NSDictionary,
            previousExpectedBody as NSDictionary
        )

        let lastRequest = self.session.lastRequest!
        XCTAssertEqual(
            "https://example.com/api/contacts/some-contact-id",
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
            contactID: "some-contact-id",
            channelID: "some-channel",
            channelType: .sms
        )

        XCTAssertTrue(response.isSuccess)
        XCTAssertEqual("some-channel", response.result!.channelID)
        XCTAssertEqual(.sms, response.result!.channelType)

        let request = self.session.lastRequest!
        XCTAssertEqual(
            "https://example.com/api/contacts/some-contact-id",
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
                value: .string("Hello"),
                date: date
            ),
            AttributeUpdate.set(
                attribute: "some-number",
                value: .number(32.0),
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
            contactID: "some-contact-id",
            tagGroupUpdates: tagUpdates,
            attributeUpdates: attributeUpdates,
            subscriptionListUpdates: listUpdates
        )

        XCTAssertTrue(response.isSuccess)

        let request = self.session.lastRequest!
        XCTAssertEqual(
            "https://example.com/api/contacts/some-contact-id",
            request.url!.absoluteString
        )

        let body = try JSONSerialization.jsonObject(
            with: request.body!,
            options: []
        ) as! [String: Any]

        let formattedDate = AirshipUtils.isoDateFormatterUTCWithDelimiter()
            .string(
                from: date
            )
        let expectedBody = [
            "attributes": [
                [
                    "action": "set",
                    "key": "some-string",
                    "timestamp": formattedDate,
                    "value": "Hello",
                ] as [String : Any],
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
        ] as [String : Any]

        XCTAssertEqual(body as NSDictionary, expectedBody as NSDictionary)
    }
}
