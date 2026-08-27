/* Copyright Airship and Contributors */

import Combine
import Foundation
import Testing

@testable @_spi(AirshipInternal) import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

/// Covers the seam between a decoded layout and the `AirshipEmbeddedInfo` the AI selector
/// ranks: `content_description` is authored on the layout root, but selection only ever
/// sees the info, so a dropped field here silently disables the feature.
@Suite("AirshipEmbeddedViewManager pending info")
@MainActor
struct AirshipEmbeddedViewManagerTest {

    @Test("content_description on the layout reaches the pending embedded info")
    func contentDescriptionReachesEmbeddedInfo() throws {
        let info = try addPending(layout: layoutJSON(contentDescription: """
        "content_description": {
          "description": "Spring sale on cat trees",
          "additional_context": [
            { "content": "Sale ends Friday", "priority": -1 },
            { "content": "Cat category" }
          ]
        },
        """))

        #expect(info.contentDescription == "Spring sale on cat trees")
        #expect(
            info.additionalContext == [
                ThomasAIContextItem(content: "Sale ends Friday", priority: -1),
                ThomasAIContextItem(content: "Cat category", priority: 0),
            ]
        )
    }

    @Test("A layout without content_description yields an empty description and context")
    func missingContentDescriptionIsEmpty() throws {
        let info = try addPending(layout: layoutJSON())

        #expect(info.contentDescription == nil)
        #expect(info.additionalContext.isEmpty)
    }

    @Test("A content_description with only a description carries no context items")
    func descriptionWithoutContext() throws {
        let info = try addPending(layout: layoutJSON(contentDescription: """
        "content_description": { "description": "Dog food deals" },
        """))

        #expect(info.contentDescription == "Dog food deals")
        #expect(info.additionalContext.isEmpty)
    }

    // MARK: - Helpers

    private func addPending(layout json: String) throws -> AirshipEmbeddedInfo {
        let layout = try JSONDecoder().decode(AirshipLayout.self, from: Data(json.utf8))
        guard case .embedded(let presentation) = layout.presentation else {
            struct NotEmbedded: Error {}
            throw NotEmbedded()
        }

        let manager = AirshipEmbeddedViewManager()
        _ = manager.addPending(
            presentation: presentation,
            layout: layout,
            delegate: TestThomasDelegate(),
            extras: nil,
            priority: 3,
            extensions: TestThomasExtensions()
        )

        var pending: [PendingEmbedded] = []
        let cancellable = manager.publisher.sink { pending = $0 }
        defer { cancellable.cancel() }

        guard let info = pending.first?.embeddedInfo else {
            struct NoPending: Error {}
            throw NoPending()
        }
        // Sanity-check the fields that already flowed, so a helper mistake can't read as
        // a content_description failure.
        #expect(info.embeddedID == "slot")
        #expect(info.priority == 3)
        return info
    }

    private func layoutJSON(contentDescription: String = "") -> String {
        """
        {
          "version": 1,
          "presentation": {
            "type": "embedded",
            "embedded_id": "slot",
            "default_placement": { "size": { "width": "100%", "height": "auto" } }
          },
          \(contentDescription)
          "view": { "type": "empty_view" }
        }
        """
    }
}
