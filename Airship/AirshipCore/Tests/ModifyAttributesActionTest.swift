/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable
import AirshipCore

@Suite(.timeLimit(.minutes(1)))
struct ModifyAttributesActionTest {

    private let channel = TestChannel()
    private let contact = TestContact()
    private let push = TestPush()
    private let date = UATestDate()
    private let action: ModifyAttributesAction

    init() async throws {
        date.dateOverride = Date()
        let channel = self.channel
        let contact = self.contact
        action = ModifyAttributesAction(
            channel: { channel },
            contact: { contact }
        )
    }

    @Test
    func testAcceptsArguments() async throws {
        let validValue = [
            "channel": [
                "set": ["name": "clive"],
            ]
        ]

        let validSituations = [
            ActionSituation.foregroundInteractiveButton,
            ActionSituation.launchedFromPush,
            ActionSituation.manualInvocation,
            ActionSituation.webViewInvocation,
            ActionSituation.automation,
            ActionSituation.foregroundPush,
            ActionSituation.backgroundInteractiveButton,
        ]

        let rejectedSituations = [
            ActionSituation.backgroundPush
        ]


        for situation in validSituations {
            let args = ActionArguments(value: try AirshipJSON.wrap(validValue), situation: situation)
            let result = await self.action.accepts(arguments: args)
            #expect(result)
        }

        for situation in validSituations {
            let args = ActionArguments(situation: situation)
            let result = await self.action.accepts(arguments: args)
            #expect(!(result))
        }

        for situation in rejectedSituations {
            let args = ActionArguments(value: try AirshipJSON.wrap(validValue), situation: situation)
            let result = await self.action.accepts(arguments: args)
            #expect(!(result))
        }
    }
    
    @Test
    func testJsonValueNewFormat() async throws {
        // name carries "attributeName#instanceId", value is the plain JSON object
        let value = [
            [
                "action": "set",
                "type": "channel",
                "name": "myAttributeName#myInstanceID",
                "value": [
                    "some_custom_key": "custom_value",
                    "exp": 1779840000
                ] as [String: Any]
            ]
        ]

        let expectedAttributes = [
            AttributeUpdate(
                attribute: "myAttributeName#myInstanceID",
                type: .set,
                jsonValue: try AirshipJSON.wrap(["some_custom_key": "custom_value", "exp": 1779840000]),
                date: self.date.now
            )
        ]

        let attributesSet = AirshipTestExpectation(description: "attributes")

        self.contact.attributeEditor = AttributesEditor(date: self.date) { _ in
            Issue.record("shouldn't be called")
        }

        self.channel.attributeEditor = AttributesEditor(date: self.date) { attributes in
            #expect(expectedAttributes == attributes)
            attributesSet.fulfill()
        }

        let _ = try await self.action.perform(arguments:
            ActionArguments(
                value: try AirshipJSON.wrap(value),
                situation: .manualInvocation
            )
        )

        await fulfillment(of: [attributesSet])
    }

    @Test
    func testJsonValueNewFormatNoExpiration() async throws {
        let value = [
            [
                "action": "set",
                "type": "channel",
                "name": "myAttributeName#myInstanceID",
                "value": [
                    "some_custom_key": "custom_value"
                ] as [String: Any]
            ]
        ]

        let expectedAttributes = [
            AttributeUpdate(
                attribute: "myAttributeName#myInstanceID",
                type: .set,
                jsonValue: try AirshipJSON.wrap(["some_custom_key": "custom_value"]),
                date: self.date.now
            )
        ]

        let attributesSet = AirshipTestExpectation(description: "attributes")

        self.contact.attributeEditor = AttributesEditor(date: self.date) { _ in
            Issue.record("shouldn't be called")
        }

        self.channel.attributeEditor = AttributesEditor(date: self.date) { attributes in
            #expect(expectedAttributes == attributes)
            attributesSet.fulfill()
        }

        let _ = try await self.action.perform(arguments:
            ActionArguments(
                value: try AirshipJSON.wrap(value),
                situation: .manualInvocation
            )
        )

        await fulfillment(of: [attributesSet])
    }

    @Test
    func testAcceptReturnsFalseForInvalidJsonValue() async throws {
        let jsons: [[[String: Any]]] = [
            // value key has no "#" → not a valid instance attribute
            [[
                "action": "set",
                "type": "channel",
                "name": "another name",
                "value": [
                    "json_test": [
                        "exp": 1012,
                        "nested": [ "foo": "bar" ]
                    ]
                ]
            ]],
            // value key has too many "#" → invalid
            [[
                "action": "set",
                "type": "channel",
                "name": "another name",
                "value": [
                    "json#te#st#": [
                        "exp": 1012,
                        "nested": [ "foo": "bar" ]
                    ]
                ]
            ]],
            // value key ends with "#" (empty instanceId) → invalid
            [[
                "action": "set",
                "type": "channel",
                "name": "another name",
                "value": [
                    "json_test#": [
                        "exp": 1012,
                        "nested": [ "foo": "bar" ]
                    ]
                ]
            ]],
            // name has too many "#" → invalid
            [[
                "action": "set",
                "type": "channel",
                "name": "my#attr#id",
                "value": [
                    "some_key": "value"
                ]
            ]],
            // name ends with "#" (empty instanceId) → invalid
            [[
                "action": "set",
                "type": "channel",
                "name": "myAttr#",
                "value": [
                    "some_key": "value"
                ]
            ]]
        ]
        
        for item in jsons {
            let args = ActionArguments(value: try AirshipJSON.wrap(item), situation: .manualInvocation)
            let result = await self.action.accepts(arguments: args)
            #expect(!(result))
        }
    }

    @Test
    func testPerform() async throws {
        let value: [String: Any] = [
            "channel": [
                "set": ["name": "clive"],
                "remove": ["zipcode"]
            ] as [String : Any],
            "named_user": [
                "set": ["some other name": "owen"],
                "remove": ["location"]
            ] as [String : Any]
        ]

        let expectedChannelAttributes = [
            AttributeUpdate(
                attribute: "zipcode",
                type: .remove,
                jsonValue: nil,
                date: self.date.now
            ),
            AttributeUpdate(
                attribute: "name",
                type: .set,
                jsonValue: "clive",
                date: self.date.now
            )
        ]

        let expectedContactAttributes = [
            AttributeUpdate(
                attribute: "location",
                type: .remove,
                jsonValue: nil,
                date: self.date.now
            ),
            AttributeUpdate(
                attribute: "some other name",
                type: .set,
                jsonValue: "owen",
                date: self.date.now
            )
        ]

        let attributesSet = AirshipTestExpectation(description: "attributes")
        attributesSet.expectedFulfillmentCount = 2

        self.channel.attributeEditor = AttributesEditor(
            date: self.date
        ) { attributes in
            #expect(expectedChannelAttributes == attributes)
            attributesSet.fulfill()
        }


        self.contact.attributeEditor = AttributesEditor(
            date: self.date
        ) { attributes in
            #expect(expectedContactAttributes == attributes)
            attributesSet.fulfill()
        }


        let _ = try await self.action.perform(arguments:
            ActionArguments(
                value: try AirshipJSON.wrap(value),
                situation: .manualInvocation
            )
        )

        await fulfillment(of: [attributesSet])

    }
    
    @Test
    func testJsonValue() async throws {
        // name carries "attributeName#instanceId", value is the plain JSON object
        let value = [
            [
                "action": "set",
                "type": "channel",
                "name": "json#test",
                "value": [
                    "exp": 1234567890,
                    "nested": ["foo": "bar"]
                ] as [String: Any]
            ]
        ]

        let expectedAttributes = [
            AttributeUpdate(
                attribute: "json#test",
                type: .set,
                jsonValue: try AirshipJSON.wrap(["nested": ["foo": "bar"], "exp": 1234567890]),
                date: self.date.now
            )
        ]
        
        let attributesSet = AirshipTestExpectation(description: "attributes")
        
        self.contact.attributeEditor = AttributesEditor(
            date: self.date
        ) { attributes in
            Issue.record("shouldn't be called")
        }

        self.channel.attributeEditor = AttributesEditor(
            date: self.date
        ) { attributes in
            #expect(expectedAttributes == attributes)
            attributesSet.fulfill()
        }
        
        let _ = try await self.action.perform(arguments:
            ActionArguments(
                value: try AirshipJSON.wrap(value),
                situation: .manualInvocation
            )
        )

        await fulfillment(of: [attributesSet])
    }
    
    @Test
    func testJsonValueNoExpiration() async throws {
        // name carries "attributeName#instanceId", value is the plain JSON object
        let value = [
            [
                "action": "set",
                "type": "channel",
                "name": "json#test",
                "value": [
                    "nested": ["foo": "bar"]
                ] as [String: Any]
            ]
        ]

        let expectedAttributes = [
            AttributeUpdate(
                attribute: "json#test",
                type: .set,
                jsonValue: try AirshipJSON.wrap(["nested": ["foo": "bar"]]),
                date: self.date.now
            )
        ]
        
        let attributesSet = AirshipTestExpectation(description: "attributes")
        
        self.contact.attributeEditor = AttributesEditor(
            date: self.date
        ) { attributes in
            Issue.record("shouldn't be called")
        }

        self.channel.attributeEditor = AttributesEditor(
            date: self.date
        ) { attributes in
            #expect(expectedAttributes == attributes)
            attributesSet.fulfill()
        }
        
        let _ = try await self.action.perform(arguments:
            ActionArguments(
                value: try AirshipJSON.wrap(value),
                situation: .manualInvocation
            )
        )

        await fulfillment(of: [attributesSet])
    }
}
