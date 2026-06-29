/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Testing

@_spi(AirshipInternal) import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite("ThomasAssociatedLabelResolver")
@MainActor
struct ThomasAssociatedLabelResolverTest {

    private let thomasState = ThomasState(onStateChange: { _ in })
    private let thomasEnvironment = ThomasEnvironment(delegate: StubThomasDelegate(), extensions: TestThomasExtensions())

    private final class StubThomasDelegate: ThomasDelegate {
        func onVisibilityChanged(isVisible: Bool, isForegrounded: Bool) {}
        func onReportingEvent(_ event: ThomasReportingEvent) {}
        func onDismissed(cancel: Bool) {}
    }

    // MARK: - Fixtures

    private func makeLayout(viewJSON: String) throws -> AirshipLayout {
        let json = """
        {
          "version": 1,
          "presentation": {
            "type": "modal",
            "default_placement": {
              "size": { "width": "100%", "height": "100%" },
              "placement": { "horizontal": "center", "vertical": "center" }
            }
          },
          "view": \(viewJSON)
        }
        """
        return try JSONDecoder().decode(AirshipLayout.self, from: Data(json.utf8))
    }

    private func makeLabelJSON(
        text: String,
        labelingViewID: String,
        viewType: String,
        associationType: String = "labels"
    ) -> String {
        """
        {
          "type": "label",
          "text": "\(text)",
          "text_appearance": {
            "font_size": 14,
            "color": {
              "default": { "type": "hex", "hex": "#000000", "alpha": 1.0 }
            }
          },
          "labels": {
            "view_id": "\(labelingViewID)",
            "type": "\(associationType)",
            "view_type": "\(viewType)"
          }
        }
        """
    }

    // MARK: - Tests

    @Test
    func mergingAddsLabelFromResponse() throws {
        let resolver = ThomasAssociatedLabelResolver(
            layout: try makeLayout(viewJSON: #"{ "type": "empty_view" }"#),
            environment: thomasEnvironment
        )

        let labelViewInfo = try JSONDecoder().decode(
            ThomasViewInfo.self,
            from: Data(makeLabelJSON(text: "Email Address", labelingViewID: "email-input", viewType: "text_input").utf8)
        )

        let merged = resolver.merging(viewInfo: labelViewInfo, environment: thomasEnvironment)

        #expect(merged.labelFor(identifier: "email-input", viewType: .textInput, thomasState: thomasState) == "Email Address")
    }

    @Test
    func mergingPreservesExistingLabels() throws {
        let resolver = ThomasAssociatedLabelResolver(
            layout: try makeLayout(viewJSON: makeLabelJSON(text: "Name", labelingViewID: "name-input", viewType: "text_input")),
            environment: thomasEnvironment
        )

        let newLabelViewInfo = try JSONDecoder().decode(
            ThomasViewInfo.self,
            from: Data(makeLabelJSON(text: "Email", labelingViewID: "email-input", viewType: "text_input").utf8)
        )

        let merged = resolver.merging(viewInfo: newLabelViewInfo, environment: thomasEnvironment)

        #expect(merged.labelFor(identifier: "name-input", viewType: .textInput, thomasState: thomasState) == "Name")
        #expect(merged.labelFor(identifier: "email-input", viewType: .textInput, thomasState: thomasState) == "Email")
    }

    @Test
    func mergingFindsNestedLabels() throws {
        let resolver = ThomasAssociatedLabelResolver(
            layout: try makeLayout(viewJSON: #"{ "type": "empty_view" }"#),
            environment: thomasEnvironment
        )

        let containerJSON = """
        {
          "type": "linear_layout",
          "direction": "vertical",
          "items": [
            {
              "view": \(makeLabelJSON(text: "Nested Label", labelingViewID: "nested-view", viewType: "text_input")),
              "size": { "width": "100%", "height": "auto" }
            }
          ]
        }
        """
        let containerViewInfo = try JSONDecoder().decode(
            ThomasViewInfo.self,
            from: Data(containerJSON.utf8)
        )

        let merged = resolver.merging(viewInfo: containerViewInfo, environment: thomasEnvironment)

        #expect(merged.labelFor(identifier: "nested-view", viewType: .textInput, thomasState: thomasState) == "Nested Label")
    }

    @Test
    func mergingIgnoresDescribesAssociation() throws {
        let resolver = ThomasAssociatedLabelResolver(
            layout: try makeLayout(viewJSON: #"{ "type": "empty_view" }"#),
            environment: thomasEnvironment
        )

        let describesLabelViewInfo = try JSONDecoder().decode(
            ThomasViewInfo.self,
            from: Data(makeLabelJSON(text: "Description", labelingViewID: "some-view", viewType: "text_input", associationType: "describes").utf8)
        )

        let merged = resolver.merging(viewInfo: describesLabelViewInfo, environment: thomasEnvironment)

        #expect(merged.labelFor(identifier: "some-view", viewType: .textInput, thomasState: thomasState) == nil)
    }

    @Test
    func originalResolverIsUnmodified() throws {
        let resolver = ThomasAssociatedLabelResolver(
            layout: try makeLayout(viewJSON: #"{ "type": "empty_view" }"#),
            environment: thomasEnvironment
        )

        let labelViewInfo = try JSONDecoder().decode(
            ThomasViewInfo.self,
            from: Data(makeLabelJSON(text: "Label", labelingViewID: "some-view", viewType: "text_input").utf8)
        )

        _ = resolver.merging(viewInfo: labelViewInfo, environment: thomasEnvironment)

        #expect(resolver.labelFor(identifier: "some-view", viewType: .textInput, thomasState: thomasState) == nil)
    }
}
