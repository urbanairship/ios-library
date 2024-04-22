/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore

final class DefaultInAppDisplayImpressionRuleProviderTest: XCTestCase {

    let provider = DefaultInAppDisplayImpressionRuleProvider()

    func testCustomMessage() throws {
        let rule = provider.impressionRules(
            for: InAppMessage(name: "woot", displayContent: .custom(.string("neat")))
        )
        XCTAssertEqual(rule, .once)
    }

    func testFullscreenMessage() throws {
        let rule = provider.impressionRules(
            for: InAppMessage(
                name: "woot",
                displayContent: .fullscreen(.init(buttons: [], template: .headerBodyMedia))
            )
        )
        XCTAssertEqual(rule, .once)
    }

    func testModalMessage() throws {
        let rule = provider.impressionRules(
            for: InAppMessage(
                name: "woot",
                displayContent: .modal(.init(buttons: [], template: .headerBodyMedia))
            )
        )
        XCTAssertEqual(rule, .once)
    }

    func testBannerMessage() throws {
        let rule = provider.impressionRules(
            for: InAppMessage(
                name: "woot",
                displayContent: .banner(.init(buttons: [], template: .mediaLeft))
            )
        )
        XCTAssertEqual(rule, .once)
    }

    func testModalThomas() throws {
        let airshipLayout = """
        {
          "version":1,
          "presentation":{
             "type":"modal",
             "default_placement":{
                "size":{
                   "width":"50%",
                   "height":"50%"
                }
             }
          },
          "view":{
             "type":"container",
             "items":[]
          }
        }
        """


        let rule = provider.impressionRules(
            for: InAppMessage(
                name: "woot",
                displayContent: .airshipLayout(
                    try! JSONDecoder().decode(AirshipLayout.self, from: airshipLayout.data(using: .utf8)!)
                )
            )
        )
        XCTAssertEqual(rule, .once)
    }

    func testBannerThomas() throws {
        let airshipLayout = """
        {
          "version":1,
          "presentation":{
             "type":"banner",
             "default_placement":{
                "position": "top",
                "size":{
                   "width":"50%",
                   "height":"50%"
                }
             }
          },
          "view":{
             "type":"container",
             "items":[]
          }
        }
        """

        let rule = provider.impressionRules(
            for: InAppMessage(
                name: "woot",
                displayContent: .airshipLayout(
                    try! JSONDecoder().decode(AirshipLayout.self, from: airshipLayout.data(using: .utf8)!)
                )
            )
        )
        XCTAssertEqual(rule, .once)
    }

    func testEmbeddedThomas() throws {
        let airshipLayout = """
        {
          "version":1,
          "presentation":{
             "type":"embedded",
             "embedded_id":"home_banner",
             "default_placement":{
                "size":{
                   "width":"50%",
                   "height":"50%"
                }
             }
          },
          "view":{
             "type":"container",
             "items":[]
          }
        }
        """

        let rule = provider.impressionRules(
            for: InAppMessage(
                name: "woot",
                displayContent: .airshipLayout(
                    try! JSONDecoder().decode(AirshipLayout.self, from: airshipLayout.data(using: .utf8)!)
                )
            )
        )
        XCTAssertEqual(rule, .interval(30.0))
    }
}
