/* Copyright Airship and Contributors */


import Testing

@testable
import AirshipCore

struct ModifyTagsActionTest {
    
    private let channel = TestChannel()
    private let contact = TestContact()
    
    private func makeAction() -> ModifyTagsAction {
        return ModifyTagsAction(
            channel: { [channel] in return channel },
            contact: { [contact] in return contact }
        )
    }
    
    @Test(
        "Test accepts arguments",
        arguments: [
            ActionSituation.foregroundInteractiveButton,
            ActionSituation.launchedFromPush,
            ActionSituation.manualInvocation,
            ActionSituation.webViewInvocation,
            ActionSituation.automation,
            ActionSituation.foregroundPush,
            ActionSituation.backgroundInteractiveButton
        ]
    )
    func testAcceptsArguments(situation: ActionSituation) async throws {
        let args = ActionArguments(
            value: try AirshipJSON.wrap(channelAddPayload),
            situation: situation
        )
        #expect(await makeAction().accepts(arguments: args))
    }
    
    @Test(
        "Rejects backgound push situation",
        arguments: [ActionSituation.backgroundPush]
    )
    func testRejectSituations(situation: ActionSituation) async throws {
        let args = ActionArguments(
            value: try AirshipJSON.wrap(channelAddPayload),
            situation: situation
        )
        #expect(!(await makeAction().accepts(arguments: args)))
    }
    
    @Test
    func testChannelAdd() async throws {
        self.channel.tags = ["channel_tag_1", "channel_tag_3"]
        mockEditors()
        
        #expect(self.channel.tags == ["channel_tag_1", "channel_tag_3"])
        
        _ = try await makeAction().perform(
            arguments: ActionArguments(
                value: try! AirshipJSON.wrap([channelAddPayload]),
                situation: .launchedFromPush
            ))
        
        #expect(self.channel.tags.sorted() == ["channel_tag_1", "channel_tag_1", "channel_tag_2", "channel_tag_3"])
    }
    
    @Test
    func testChannelAddGroup() async throws {
        var groupUpdates: [TagGroupUpdate] = []
        mockEditors(
            channelGroup: TagGroupsEditor { groupUpdates = $0 }
        )
        
        #expect(groupUpdates == [])
        
        _ = try await makeAction().perform(
            arguments: ActionArguments(
                value: try! AirshipJSON.wrap([channelAddGroupPayload]),
                situation: .launchedFromPush
            ))
        
        #expect(groupUpdates == [
            .init(
                group: "test_group",
                tags: ["channel_tag_1", "channel_tag_2"],
                type: .add)
        ])
    }
    
    @Test
    func testChannelRemove() async throws {
        self.channel.tags = ["channel_tag_1", "channel_tag_3"]
        mockEditors()
        #expect(self.channel.tags == ["channel_tag_1", "channel_tag_3"])
        
        _ = try await makeAction().perform(
            arguments: ActionArguments(
                value: try! AirshipJSON.wrap([channelRemovePayload]),
                situation: .launchedFromPush
            ))
        
        #expect(self.channel.tags.sorted() == ["channel_tag_3"])
    }
    
    @Test
    func testChannelRemoveGroup() async throws {
        var groupUpdates: [TagGroupUpdate] = []
        mockEditors(channelGroup: TagGroupsEditor { groupUpdates = $0 })
        
        #expect(groupUpdates == [])
        
        _ = try await makeAction().perform(
            arguments: ActionArguments(
                value: try! AirshipJSON.wrap([channelRemoveGroupPayload]),
                situation: .launchedFromPush
            ))
        
        #expect(groupUpdates == [
            .init(
                group: "test_group",
                tags: ["channel_tag_1", "channel_tag_2"],
                type: .remove)
        ])
    }
    
    @Test("Throws on invalid JSON")
    func testThrowsOnInvalidChannelJson() async throws {
        mockEditors()
        
        await #expect(throws: DecodingError.self) {
            _ = try await makeAction().perform(
                arguments: ActionArguments(
                    value: try! AirshipJSON.wrap([channelInvalidPayload]),
                    situation: .launchedFromPush
                ))
        }
    }
    
    @Test
    func testAddContactTags() async throws {
        var groupUpdates: [TagGroupUpdate] = []
        mockEditors(contactGroup: TagGroupsEditor { groupUpdates = $0 })
        
        #expect(groupUpdates == [])
        
        _ = try await makeAction().perform(
            arguments: ActionArguments(
                value: try! AirshipJSON.wrap([contactAddPayload]),
                situation: .launchedFromPush
            ))
        
        #expect(groupUpdates == [
            .init(
                group: "test_group",
                tags: ["contact_tag_1", "contact_tag_2"],
                type: .add)
        ])
    }
    
    @Test
    func testRemoveContactTags() async throws {
        var groupUpdates: [TagGroupUpdate] = []
        mockEditors(contactGroup: TagGroupsEditor { groupUpdates = $0 })
        
        #expect(groupUpdates == [])
        
        _ = try await makeAction().perform(
            arguments: ActionArguments(
                value: try! AirshipJSON.wrap([contactRemovePayload]),
                situation: .launchedFromPush
            ))
        
        #expect(groupUpdates == [
            .init(
                group: "test_group",
                tags: ["contact_tag_1", "contact_tag_2"],
                type: .remove)
        ])
    }
    
    @Test("Throws on invalid payload")
    func testThrowsOnInvalidContactPayload() async throws {
        mockEditors()
        
        await #expect(throws: DecodingError.self) {
            _ = try await makeAction().perform(
                arguments: ActionArguments(
                    value: try! AirshipJSON.wrap(contactInvalidPayload),
                    situation: .launchedFromPush
                ))
        }
    }
    
    @Test
    func testMultipleOperations() async throws {
        self.channel.tags = ["channel_tag_1", "channel_tag_3"]
        #expect(self.channel.tags.sorted() == ["channel_tag_1", "channel_tag_3"])
        
        var contactUpdate: [TagGroupUpdate] = []
        var channelUpdates: [TagGroupUpdate] = []
        mockEditors(
            channelGroup: TagGroupsEditor { channelUpdates = $0 },
            contactGroup: TagGroupsEditor { contactUpdate = $0 }
        )
        
        #expect(channelUpdates == [])
        #expect(contactUpdate == [])
        
        _ = try await makeAction().perform(
            arguments: ActionArguments(
                value: try! AirshipJSON.wrap([
                    contactRemovePayload,
                    channelAddPayload,
                    channelAddGroupPayload,
                    channelRemovePayload
                ]),
                situation: .launchedFromPush
            ))
        
        #expect(self.channel.tags.sorted() == ["channel_tag_3"])
        #expect(contactUpdate == [
            .init(group: "test_group", tags: ["contact_tag_1", "contact_tag_2"], type: .remove),
        ])
        
        #expect(channelUpdates == [
            .init(group: "test_group", tags: ["channel_tag_1", "channel_tag_2"], type: .add),
        ])
    }
    
    private func mockEditors(
        channelGroup: TagGroupsEditor = TagGroupsEditor { _ in },
        contactGroup: TagGroupsEditor = TagGroupsEditor { _ in }
    ) {
        self.contact.tagGroupEditor = contactGroup
        self.channel.tagGroupEditor = channelGroup
    }
    
    private let channelAddPayload: [String: Any] = [
        "action": "add",
        "tags": [
          "channel_tag_1",
          "channel_tag_2"
        ],
        "type": "channel"
    ]
    private let channelAddGroupPayload: [String: Any] = [
        "action": "add",
        "group": "test_group",
        "tags": [
          "channel_tag_1",
          "channel_tag_2"
        ],
        "type": "channel"
    ]
    private let channelRemovePayload: [String: Any] = [
        "action": "remove",
        "tags": [
          "channel_tag_1",
          "channel_tag_2"
        ],
        "type": "channel"
    ]
    private let channelRemoveGroupPayload: [String: Any] = [
        "action": "remove",
        "group": "test_group",
        "tags": [
          "channel_tag_1",
          "channel_tag_2"
        ],
        "type": "channel"
    ]
    
    private let contactAddPayload: [String: Any] = [
        "action": "add",
        "group": "test_group",
        "tags": [
          "contact_tag_1",
          "contact_tag_2"
        ],
        "type": "contact"
    ]
    private let contactRemovePayload: [String: Any] = [
        "action": "remove",
        "group": "test_group",
        "tags": [
          "contact_tag_1",
          "contact_tag_2"
        ],
        "type": "contact"
    ]
    
    private let channelInvalidPayload: [String: Any] = [
        "action": "remove",
        "type": "channel"
    ]
    
    private let contactInvalidPayload: [String: Any] = [
        "action": "remove",
        "tags": [
          "contact_tag_1",
          "contact_tag_2"
        ],
        "type": "contact"
    ]
    
}
