/* Copyright Airship and Contributors */

import Testing
import Foundation

@_spi(AirshipInternal) import AirshipBasement
@testable import AirshipCore

@Suite struct ContactAPIClientTest {

    private let session: TestAirshipRequestSession = TestAirshipRequestSession()
    private var contactAPIClient: ContactAPIClient!
    private let config: RuntimeConfig = RuntimeConfig.testConfig()
    private let currentLocale = Locale(identifier: "fr-CA")

    init() {
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

    @Test
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
                channelAssociatedDate: AirshipDateFormatter.date(from: "2022-12-29T10:15:30.00")!,
                contactID: "1a32e8c7-5a73-47c0-9716-99fd3d41924b",
                isAnonymous: true
            ),
            token: "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJLSHVNTE15RmVmYjdoeXR3WkV5VTF4IiwiaWF0IjoxNjAyMDY4NDIxLCJleHAiOjE2MDIwNjg0MjEsInN1YiI6InVMa2hSaktBYzVXQW1SdTFPTFZSVncifQ.kJPu3enbLJMX10xEtzlxxeum66R2ZWLs02OSVPhjomQ",
            tokenExpiresInMilliseconds: 3600000
        )

        #expect(response.isSuccess)
        #expect(response.result! == expected)

        let request = session.lastRequest!

        let requestBody = try AirshipJSON.from(data: request.body).unWrap() as! [String: AnyHashable]
        let expectedBody: [String: AnyHashable] = [
            "device_info": [
                "device_type": "ios"
            ],
            "action": [
                "type": "identify",
                "named_user_id": "my-named-user",
                "possibly_orphaned_contact_id": "1a32e8c7-5a73-47c0-9716-99fd3d41924c"
              ]
            ]

        #expect(expectedBody == requestBody)
        #expect(request.url?.absoluteString == "\(config.deviceAPIURL!)/api/contacts/identify/v2")
        #expect(request.method == "POST")
        #expect(request.auth == .generatedChannelToken(identifier: "test_channel"))
        #expect(
            request.headers ==
            [
                "Content-Type": "application/json",
                "Accept": "application/vnd.urbanairship+json; version=3;",
            ]
        )
    }

    @Test
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
                channelAssociatedDate: AirshipDateFormatter.date(from: "2022-12-29T10:15:30.00")!,
                contactID: "1a32e8c7-5a73-47c0-9716-99fd3d41924b",
                isAnonymous: true
            ),
            token: "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJLSHVNTE15RmVmYjdoeXR3WkV5VTF4IiwiaWF0IjoxNjAyMDY4NDIxLCJleHAiOjE2MDIwNjg0MjEsInN1YiI6InVMa2hSaktBYzVXQW1SdTFPTFZSVncifQ.kJPu3enbLJMX10xEtzlxxeum66R2ZWLs02OSVPhjomQ",
            tokenExpiresInMilliseconds: 3600000
        )

        #expect(response.isSuccess)
        #expect(response.result! == expected)

        let request = session.lastRequest!

        let requestBody = try AirshipJSON.from(data: request.body).unWrap() as! [String: AnyHashable]
        let expectedBody: [String: AnyHashable] = [
            "device_info": [
                "device_type": "ios"
            ],
            "action": [
                "type": "resolve",
                "contact_id": "some contact id",
                "possibly_orphaned_contact_id": "1a32e8c7-5a73-47c0-9716-99fd3d41924c"
              ]
            ]

        #expect(expectedBody == requestBody)
        #expect(request.url?.absoluteString == "https://device-api.urbanairship.com/api/contacts/identify/v2")
        #expect(request.method == "POST")
        #expect(request.auth == .generatedChannelToken(identifier: "test_channel"))
        #expect(
            request.headers ==
            [
                "Content-Type": "application/json",
                "Accept": "application/vnd.urbanairship+json; version=3;",
            ]
        )
    }

    @Test
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
                channelAssociatedDate: AirshipDateFormatter.date(from: "2022-12-29T10:15:30.00")!,
                contactID: "1a32e8c7-5a73-47c0-9716-99fd3d41924b",
                isAnonymous: true
            ),
            token: "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJLSHVNTE15RmVmYjdoeXR3WkV5VTF4IiwiaWF0IjoxNjAyMDY4NDIxLCJleHAiOjE2MDIwNjg0MjEsInN1YiI6InVMa2hSaktBYzVXQW1SdTFPTFZSVncifQ.kJPu3enbLJMX10xEtzlxxeum66R2ZWLs02OSVPhjomQ",
            tokenExpiresInMilliseconds: 3600000
        )

        #expect(response.isSuccess)
        #expect(response.result! == expected)

        let request = session.lastRequest!

        let requestBody = try AirshipJSON.from(data: request.body).unWrap() as! [String: AnyHashable]
        let expectedBody: [String: AnyHashable] = [
            "device_info": [
                "device_type": "ios"
            ],
            "action": [
                "type": "reset",
                "possibly_orphaned_contact_id": "1a32e8c7-5a73-47c0-9716-99fd3d41924c"
              ]
            ]

        #expect(expectedBody == requestBody)
        #expect(request.url?.absoluteString == "\(config.deviceAPIURL!)/api/contacts/identify/v2")
        #expect(request.method == "POST")
        #expect(request.auth == .generatedChannelToken(identifier: "test_channel"))
        #expect(
            request.headers ==
            [
                "Content-Type": "application/json",
                "Accept": "application/vnd.urbanairship+json; version=3;",
            ]
        )
    }

    @Test
    func testRegisterEmail() async throws {
        self.session.data = """
            {
                "channel_id": "some-channel",
            }
            """
            .data(using: .utf8)
        let date = Date()
        let response  = try await contactAPIClient.registerEmail(
            contactID: "some-contact-id",
            address: "ua@airship.com",
            options: EmailRegistrationOptions.options(
                transactionalOptedIn: date,
                properties: ["interests": "newsletter"],
                doubleOptIn: true
            ),
            locale: currentLocale
        )

        #expect(response.isSuccess)
        if let associatedChannel = response.result, case .email = associatedChannel.channelType {
            #expect("some-channel" == associatedChannel.channelID)
            let previousRequest = try #require(self.session.previousRequest)
            #expect(
                "\(config.deviceAPIURL!)/api/channels/restricted/email" ==
                previousRequest.url!.absoluteString
            )

            let previousBody = try JSONSerialization.jsonObject(
                with: previousRequest.body!,
                options: []
            ) as! [String : AnyHashable]

            let previousExpectedBody: [String : AnyHashable] = [
                "channel": [
                    "type": "email",
                    "address": "ua@airship.com",
                    "timezone": TimeZone.current.identifier,
                    "locale_country": "CA",
                    "locale_language": "fr",
                    "transactional_opted_in": AirshipDateFormatter.string(
                        fromDate: date,
                        format: .iso8601
                    ),
                ],
                "opt_in_mode": "double",
                "properties": [
                    "interests": "newsletter"
                ],
            ]

            #expect(
                previousBody ==
                previousExpectedBody
            )

            let lastRequest = self.session.lastRequest!
            #expect(
                "\(config.deviceAPIURL!)/api/contacts/some-contact-id" ==
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
            #expect(
                lastBody ==
                lastExpectedBody
            )
        } else {
            Issue.record("Error: Invalid associated channel type")
        }
        

    }

    @Test
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

        #expect(response.isSuccess)

        if let associatedChannel = response.result, case .sms = associatedChannel.channelType {
            #expect("some-channel" == associatedChannel.channelID)
            
            let previousRequest = try #require(self.session.previousRequest)
            #expect(
                "https://device-api.urbanairship.com/api/channels/restricted/sms" ==
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
                "locale_country": currentLocale.getRegionCode(),
                "locale_language": currentLocale.getLanguageCode(),
            ]
            #expect(
                previousBody as! NSDictionary ==
                previousExpectedBody as! NSDictionary
            )
            
            let lastRequest = self.session.lastRequest!
            #expect(
                "https://device-api.urbanairship.com/api/contacts/some-contact-id" ==
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
            #expect(
                lastBody as! NSDictionary ==
                lastExpectedBody as! NSDictionary
            )
        } else {
            Issue.record("Error: Invalid associated channel type")
        }
    }

    @Test
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

        #expect(response.isSuccess)
        if let associatedChannel = response.result, case .open = associatedChannel.channelType {
            #expect("some-channel" == associatedChannel.channelID)
            
            let previousRequest = try #require(self.session.previousRequest)
            #expect(
                "https://device-api.urbanairship.com/api/channels/restricted/open" ==
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
                    "locale_country": currentLocale.getRegionCode(),
                    "locale_language": currentLocale.getLanguageCode(),
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
            #expect(
                previousBody as! NSDictionary ==
                previousExpectedBody as NSDictionary
            )
            
            let lastRequest = self.session.lastRequest!
            #expect(
                "https://device-api.urbanairship.com/api/contacts/some-contact-id" ==
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
            #expect(
                lastBody as! NSDictionary ==
                lastExpectedBody as! NSDictionary
            )
        } else {
            Issue.record("Error: Invalid associated channel type")
        }
    }

    @Test
    func testAssociateChannel() async throws {
        let response = try await contactAPIClient.associateChannel(
            contactID: "some-contact-id",
            channelID: "some-channel",
            channelType: .sms
        )

        #expect(response.isSuccess)

        if let associatedChannel = response.result, case .sms = associatedChannel.channelType {
            #expect("some-channel" == associatedChannel.channelID)
            
            let request = self.session.lastRequest!
            #expect(
                "https://device-api.urbanairship.com/api/contacts/some-contact-id" ==
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
            #expect(body as! NSDictionary == expectedBody as! NSDictionary)
        } else {
            Issue.record("Error: Invalid associated channel type")
        }
    }

    @Test
    func testDisassociateRegistered() async throws {
        let expectedChannelType: ChannelType = .email
        let expectedChannelID: String = "some channel"
        let expectedContactID: String = "contact"

        let response = try await contactAPIClient.disassociateChannel(
            contactID: expectedContactID,
            disassociateOptions: DisassociateOptions(
                channelID: expectedChannelID,
                channelType: expectedChannelType,
                optOut: true
            )
        )
        #expect(response.isSuccess)

        let request = self.session.lastRequest!
        #expect(
            "https://device-api.urbanairship.com/api/contacts/disassociate/\(expectedContactID)" ==
            request.url!.absoluteString
        )

        let body = try JSONSerialization.jsonObject(
            with: request.body!,
            options: []
        ) as! [String: Any]

        let expectedBody = [
            "channel_type": expectedChannelType.rawValue,
            "channel_id": expectedChannelID,
            "opt_out": true
        ] as [String : Any]

        #expect(body as NSDictionary == expectedBody as NSDictionary)
    }

    @Test
    func testDisassociatePendingEmail() async throws {
        let expectedChannelType: ChannelType = .email
        let expectedEmailAddress: String = "some@email.com"
        let expectedContactID: String = "contact"

        let response = try await contactAPIClient.disassociateChannel(
            contactID: expectedContactID,
            disassociateOptions: DisassociateOptions(
                emailAddress: expectedEmailAddress,
                optOut: false
            )
        )

        #expect(response.isSuccess)

        let request = self.session.lastRequest!
        #expect(
            "https://device-api.urbanairship.com/api/contacts/disassociate/\(expectedContactID)" ==
            request.url!.absoluteString
        )

        let body = try JSONSerialization.jsonObject(
            with: request.body!,
            options: []
        ) as! [String: Any]

        let expectedBody = [
            "channel_type": expectedChannelType.rawValue,
            "email_address": expectedEmailAddress,
            "opt_out": false
        ] as [String : Any]

        #expect(body as NSDictionary == expectedBody as NSDictionary)
    }

    @Test
    func testDisassociatePendingSMS() async throws {
        let expectedChannelType: ChannelType = .sms
        let expectedMSISDN: String = "12345"
        let expectedSender: String = "56789"

        let expectedContactID: String = "contact"

        let response = try await contactAPIClient.disassociateChannel(contactID: expectedContactID, disassociateOptions: DisassociateOptions(msisdn: expectedMSISDN, senderID: expectedSender, optOut: false))

        #expect(response.isSuccess)

        let request = self.session.lastRequest!
        #expect(
            "https://device-api.urbanairship.com/api/contacts/disassociate/\(expectedContactID)" ==
            request.url!.absoluteString
        )

        let body = try JSONSerialization.jsonObject(
            with: request.body!,
            options: []
        ) as! [String: Any]

        let expectedBody = [
            "channel_type": expectedChannelType.rawValue,
            "msisdn": expectedMSISDN,
            "sender": expectedSender,
            "opt_out": false
        ] as [String : Any]

        #expect(body as NSDictionary == expectedBody as NSDictionary)
    }

    @Test
    func testResendEmail() async throws {
        let expectedChannelType: ChannelType = .email
        let expectedEmail: String = "test@email.com"

        let expectedResendOptions = ResendOptions(emailAddress: expectedEmail)

        let response = try await contactAPIClient.resend(resendOptions: expectedResendOptions)
        #expect(response.isSuccess)

        let request = self.session.lastRequest!
        #expect(
            "https://device-api.urbanairship.com/api/channels/resend" ==
            request.url!.absoluteString
        )

        let body = try JSONSerialization.jsonObject(
            with: request.body!,
            options: []
        ) as! [String: Any]

        let expectedBody = [
            "channel_type": expectedChannelType.rawValue,
            "email_address": expectedEmail
        ] as [String : Any]

        #expect(body as NSDictionary == expectedBody as NSDictionary)
    }

    @Test
    func testResendSMS() async throws {
        let expectedChannelType: ChannelType = .sms
        let expectedMSISDN: String = "1234"
        let expectedSenderID: String = "1234"

        let expectedResendOptions = ResendOptions(msisdn: expectedMSISDN, senderID: expectedSenderID)

        let response = try await contactAPIClient.resend(resendOptions: expectedResendOptions)
        #expect(response.isSuccess)

        let request = self.session.lastRequest!
        #expect(
            "https://device-api.urbanairship.com/api/channels/resend" ==
            request.url!.absoluteString
        )

        let body = try JSONSerialization.jsonObject(
            with: request.body!,
            options: []
        ) as! [String: Any]

        let expectedBody = [
            "channel_type": expectedChannelType.rawValue,
            "sender": expectedSenderID,
            "msisdn": expectedMSISDN
        ] as [String : Any]

        #expect(body as NSDictionary == expectedBody as NSDictionary)
    }

    @Test
    func testResendChannel() async throws {
        let expectedChannelType: ChannelType = .email
        let expectedChannelID: String = "some channel"
        let expectedResendOptions = ResendOptions(channelID: expectedChannelID, channelType: expectedChannelType)

        let response = try await contactAPIClient.resend(resendOptions: expectedResendOptions)
        #expect(response.isSuccess)

        let request = self.session.lastRequest!
        #expect(
            "https://device-api.urbanairship.com/api/channels/resend" ==
            request.url!.absoluteString
        )

        let body = try JSONSerialization.jsonObject(
            with: request.body!,
            options: []
        ) as! [String: Any]

        let expectedBody = [
            "channel_type": expectedChannelType.rawValue,
            "channel_id": expectedChannelID
        ] as [String : Any]

        #expect(body as NSDictionary == expectedBody as NSDictionary)
    }

    @Test
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
            contactID: "some-contact-id",
            tagGroupUpdates: tagUpdates,
            attributeUpdates: attributeUpdates,
            subscriptionListUpdates: listUpdates
        )

        #expect(response.isSuccess)

        let request = self.session.lastRequest!
        #expect(
            "https://device-api.urbanairship.com/api/contacts/some-contact-id" ==
            request.url!.absoluteString
        )

        let body = try JSONSerialization.jsonObject(
            with: request.body!,
            options: []
        ) as! [String: Any]

        let attributeFormattedDate = AirshipDateFormatter.string(fromDate: date, format: .iso8601WithMilliseconds)
        let subscriptionFormattedDate = AirshipDateFormatter.string(fromDate: date, format: .iso8601)

        let expectedBody = [
            "attributes": [
                [
                    "action": "set",
                    "key": "some-string",
                    "timestamp": attributeFormattedDate,
                    "value": "Hello",
                ] as [String : Any],
                [
                    "action": "set",
                    "key": "some-number",
                    "timestamp": attributeFormattedDate,
                    "value": 32,
                ],
                [
                    "action": "remove",
                    "key": "some-remove",
                    "timestamp": attributeFormattedDate,
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
                    "timestamp": subscriptionFormattedDate,
                ],
                [
                    "action": "unsubscribe",
                    "list_id": "foo",
                    "scope": "app",
                    "timestamp": subscriptionFormattedDate,
                ],
            ],
        ] as [String : Any]

        #expect(body as NSDictionary == expectedBody as NSDictionary)
    }
}
