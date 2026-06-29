/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite(.timeLimit(.minutes(1)))
struct ThomasValidationTests {

    @Test
    func validVersions() throws {
        try (AirshipLayout.minLayoutVersion...AirshipLayout.maxLayoutVersion)
            .map { layout(version: $0).data(using: .utf8)! }
            .forEach {
                let layout = try JSONDecoder().decode(AirshipLayout.self, from: $0)
                #expect(layout.validate())
            }
    }

    @Test
    func invalidVersions() throws {
        try ([AirshipLayout.minLayoutVersion - 1, AirshipLayout.maxLayoutVersion + 1])
            .map { layout(version: $0).data(using: .utf8)! }
            .forEach {
                let layout = try JSONDecoder().decode(AirshipLayout.self, from: $0)
                #expect(!layout.validate())
            }
    }

    private func layout(version: Int) -> String {
        """
        {
            "presentation": {
                "type": "modal",
                "default_placement": {
                    "size": {
                        "width": "60%",
                        "height": "60%"
                    },
                    "placement": {
                        "horizontal": "center",
                        "vertical": "center"
                    }
                }
            },
            "version": \(version),
            "view": {
              "type": "empty_view",
            }
        }
        """
    }
}
