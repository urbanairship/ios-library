/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class ThomasValidationTests: XCTestCase {

    func testValidVersions() throws {
        try (AirshipLayout.minLayoutVersion...AirshipLayout.maxLayoutVersion)
            .map { self.layout(version: $0).data(using: .utf8)! }
            .forEach {
                let layout = try JSONDecoder().decode(AirshipLayout.self, from: $0)

                XCTAssertTrue(
                    layout.validate()
                )
            }
    }

    func testInvalidVersions() throws {
        try ([AirshipLayout.minLayoutVersion - 1, AirshipLayout.maxLayoutVersion + 1])
            .map { self.layout(version: $0).data(using: .utf8)! }
            .forEach {
                let layout = try JSONDecoder().decode(AirshipLayout.self, from: $0)
                XCTAssertFalse(
                    layout.validate()
                )
            }
    }

    func layout(version: Int) -> String {
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
