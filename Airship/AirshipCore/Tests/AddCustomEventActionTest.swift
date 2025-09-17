/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class AddCustomEventActionTest: AirshipBaseTest {

    private let analytics = TestAnalytics()
    private var airship: TestAirshipInstance!
    private let action = AddCustomEventAction()

    @MainActor
    override func setUpWithError() throws {
        airship = TestAirshipInstance()
        self.airship.components = [analytics]
        self.airship.makeShared()
    }
    
    // Test custom event action accepts all the situations.
    func testAcceptsArgumentsAllSituations() async throws {
        let dict = ["event_name": "event name"]
        await verifyAcceptsArguments(withValue: try AirshipJSON.wrap(dict), shouldAccept: true)
    }
    
    func testAcceptsNewEventNameAndValueAllSituations() async throws {
        let dict = ["name": "name"]
        await verifyAcceptsArguments(withValue: try AirshipJSON.wrap(dict), shouldAccept: true)
    }
    
    
    // Test that it rejects invalid argument values.
    func testAcceptsArgumentsNo() async throws {
        let invalidDict = ["invalid_key": "event name"]
        await verifyAcceptsArguments(withValue: try AirshipJSON.wrap(invalidDict), shouldAccept: false)
        
        await verifyAcceptsArguments(withValue: AirshipJSON.null, shouldAccept: false)
        await verifyAcceptsArguments(withValue: try AirshipJSON.wrap("not a dictionary"), shouldAccept: false)
        await verifyAcceptsArguments(withValue: AirshipJSON.object([:]), shouldAccept: false)
        await verifyAcceptsArguments(withValue: AirshipJSON.array([]), shouldAccept: false)
    }

    
    // Test performing the action actually creates and adds the event from a NSNumber event value.
    func testPerformNSNumber() async throws {
        let dict: [String: Any] = [
            "event_name": "event name",
            "transaction_id": "transaction ID",
            "event_value": 123.45,
            "interaction_type": "interaction type",
            "interaction_id": "interaction ID"
        ]
        
        let args = ActionArguments(
            value: try AirshipJSON.wrap(dict),
            situation: .manualInvocation
        )
        
        try await verifyPerformWithArgs(args: args, expectedResult: nil)
        
        XCTAssertEqual(1, self.analytics.customEvents.count);
        let event  = try XCTUnwrap(self.analytics.customEvents.first)
        XCTAssertEqual("event name", event.eventName);
        XCTAssertEqual("transaction ID", event.transactionID);
        XCTAssertEqual("interaction type", event.interactionType);
        XCTAssertEqual("interaction ID", event.interactionID);
        XCTAssertEqual(123.45, event.eventValue);
    }
    
    
     // Test performing the action actually creates and adds the event from a string
     // event value.
    func testPerformString() async throws {
        let dict: [String : Any] = [
            "event_name": "event name",
            "transaction_id": "transaction ID",
            "event_value": "123.45",
            "interaction_type": "interaction type",
            "interaction_id": "interaction ID"
        ]
    
        let args = ActionArguments(
            value: try AirshipJSON.wrap(dict),
            situation: .manualInvocation
        )
        
        try await verifyPerformWithArgs(args: args, expectedResult: nil)
    
        XCTAssertEqual(1, self.analytics.customEvents.count);
        let event  = try XCTUnwrap(self.analytics.customEvents.first)
        XCTAssertEqual("event name", event.eventName);
        XCTAssertEqual("transaction ID", event.transactionID);
        XCTAssertEqual("interaction type", event.interactionType);
        XCTAssertEqual("interaction ID", event.interactionID);
        XCTAssertEqual(123.45, event.eventValue);
    }
    
   func testPerformPrefersNewNames() async throws {
       let dict: [String : Any] = [
        "name": "new event name",
        "event_name": "event name",
        "transaction_id": "transaction ID",
        "event_value": "123.45",
        "value": "321.21",
        "interaction_type": "interaction type",
        "interaction_id": "interaction ID"
       ]
   
       let args = ActionArguments(
           value: try AirshipJSON.wrap(dict),
           situation: .manualInvocation
       )
       
       try await verifyPerformWithArgs(args: args, expectedResult: nil)
   
       XCTAssertEqual(1, self.analytics.customEvents.count);
       let event  = try XCTUnwrap(self.analytics.customEvents.first)
       XCTAssertEqual("new event name", event.eventName);
       XCTAssertEqual("transaction ID", event.transactionID);
       XCTAssertEqual("interaction type", event.interactionType);
       XCTAssertEqual("interaction ID", event.interactionID);
       XCTAssertEqual(321.21, event.eventValue);
   }
    
    
     // Test perform with invalid event name should result in error.
    func testPerformInvalidCustomEventName() async throws {
        let dict: [String: Any] = [
            "event_name": "",
            "transaction_id": "transaction ID",
            "event_value": "123.45",
            "interaction_type": "interaction type",
            "interaction_id": "interaction ID"
        ]
    
        let args = ActionArguments(
            value: try AirshipJSON.wrap(dict),
            situation: .manualInvocation
        )
        
        do {
            try await verifyPerformWithArgs(args: args, expectedResult: nil)
            XCTFail("Should throw")
        } catch {
            XCTAssertNotNil(error)
        }
        
    }
    
    
     // Test auto filling in the interaction ID and type from an mcrap when left
     // empty.
    func testInteractionEmptyMCRAP() async throws {
        
        let eventPayload = [
            "event_name": "event name",
            "transaction_id": "transaction ID",
            "event_value": "123.45"
        ]
    
        let args = ActionArguments(
            value: try AirshipJSON.wrap(eventPayload),
            situation: .manualInvocation,
            metadata: [ActionArguments.inboxMessageIDMetadataKey: "message ID"]
        )

        try await verifyPerformWithArgs(args: args, expectedResult: nil)
    
        XCTAssertEqual(1, self.analytics.customEvents.count);
        let event  = try XCTUnwrap(self.analytics.customEvents.first)
        XCTAssertEqual("event name", event.eventName);
        XCTAssertEqual("transaction ID", event.transactionID);
        XCTAssertEqual("ua_mcrap", event.interactionType);
        XCTAssertEqual("message ID", event.interactionID);
        XCTAssertEqual(123.45, event.eventValue);
    }
    
     // Test not modifying the interaction ID and type when it is set and triggered
    // from an mcrap.
    func testInteractionSetMCRAP() async throws {
        let eventPayload = [
            "event_name": "event name",
            "transaction_id": "transaction ID",
            "event_value": "123.45",
            "interaction_type": "interaction type",
            "interaction_id": "interaction ID"
        ]
    
        let args = ActionArguments(
            value: try AirshipJSON.wrap(eventPayload),
            situation: .manualInvocation,
            metadata: [ActionArguments.inboxMessageIDMetadataKey: "message ID"]
        )
        
        try await verifyPerformWithArgs(args: args, expectedResult: nil)
    
        XCTAssertEqual(1, self.analytics.customEvents.count);
        let event  = try XCTUnwrap(self.analytics.customEvents.first)
        XCTAssertEqual("event name", event.eventName);
        XCTAssertEqual("transaction ID", event.transactionID);
        XCTAssertEqual("interaction type", event.interactionType);
        XCTAssertEqual("interaction ID", event.interactionID);
        XCTAssertEqual(123.45, event.eventValue);
    }
    
    
    
    // Test setting the conversion send ID on the event if the action arguments has
    // a push payload meta data.
    func testSetConversionSendIdFromPush() async throws {
        let dict: [String: String] = [
            "event_name": "event name",
            "transaction_id": "transaction ID",
            "event_value": "123.45",
            "interaction_type": "interaction type",
            "interaction_id": "interaction ID"
        ]
    
        let notification: [String: Any] = [
            "_": "send ID",
            "com.urbanairship.metadata": "send metadata",
            "apns": [
                "alert": "oh hi"
            ]
        ]
    
        let args = ActionArguments(
            value: try AirshipJSON.wrap(dict),
            situation: .manualInvocation,
            metadata: [ActionArguments.pushPayloadJSONMetadataKey: try AirshipJSON.wrap(notification)]
        )
    
        try await verifyPerformWithArgs(args: args, expectedResult: nil)
    
        XCTAssertEqual(1, self.analytics.customEvents.count);
        let event  = try XCTUnwrap(self.analytics.customEvents.first)
        XCTAssertEqual("event name", event.eventName);
        XCTAssertEqual("transaction ID", event.transactionID);
        XCTAssertEqual("interaction type", event.interactionType);
        XCTAssertEqual("interaction ID", event.interactionID);
        XCTAssertEqual("send ID", event.data["conversion_send_id"] as! String);
        XCTAssertEqual("send metadata", event.data["conversion_metadata"] as! String);
        XCTAssertEqual(123.45, event.eventValue);
    }
    
    // Test settings properties on a custom event.
    //
    func testSetCustomProperties() async throws {
        let dict: [String : Any] =  [
            "event_name": "event name",
            "properties":
                [
                    "array": ["string", "another string"],
                    "bool": true,
                    "number": 123,
                    "string": "string value"
                ] as [String : Any]
        ]
    
    
        let args = ActionArguments(
            value: try AirshipJSON.wrap(dict),
            situation: .manualInvocation
        )

        try await verifyPerformWithArgs(args: args, expectedResult: nil)
    
        XCTAssertEqual(1, self.analytics.customEvents.count);
        let event  = try XCTUnwrap(self.analytics.customEvents.first)
        XCTAssertEqual("event name", event.eventName);
        XCTAssertEqual(try! AirshipJSON.wrap(dict["properties"]), try! AirshipJSON.wrap(event.properties));
    }
    
    
    // Helper method to verify accepts arguments.
    func verifyAcceptsArguments(
        withValue value: AirshipJSON,
        shouldAccept: Bool
    ) async {
        
        let situations = [ActionSituation.webViewInvocation,
                          .foregroundPush,
                          .backgroundPush,
                          .launchedFromPush,
                          .manualInvocation,
                          .foregroundInteractiveButton,
                          .backgroundInteractiveButton,
                          .automation]
        
        for situation in situations {
            let args = ActionArguments(value: value, situation: situation)
            var accepts = false
            do {
                try await verifyPerformWithArgs(args: args)
                accepts = true
            } catch {
                accepts = false
            }
            
            if (shouldAccept) {
                XCTAssertTrue(accepts, "Add custom event action should accept value  \(String(describing: value)) in situation \(situation)");
            } else {
                XCTAssertFalse(accepts, "Add custom event action should not accept value \(String(describing: value)) in situation \(situation)");
            }
        }
    }
    
    // Helper method to verify perform.
    func verifyPerformWithArgs(args: ActionArguments, expectedResult: AirshipJSON? = nil) async throws {
    
        let result = try await self.action.perform(arguments: args)
          
        XCTAssertEqual(result, expectedResult, "Result status should match expected result status.");
    }
    
}
