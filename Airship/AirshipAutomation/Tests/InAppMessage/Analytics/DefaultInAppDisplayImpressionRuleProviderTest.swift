/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal)
import AirshipAutomation
import AirshipCore
@_spi(AirshipInternal) import AirshipScenes

struct DefaultInAppDisplayImpressionRuleProviderTest {

    let provider = DefaultInAppDisplayImpressionRuleProvider()

    @Test
    func testCustomMessage() throws {
        let rule = provider.impressionRules(
            for: InAppMessage(name: "woot", displayContent: .custom(.string("neat")))
        )
        #expect(rule == .once)
    }

    @Test
    func testFullscreenMessage() throws {
        let rule = provider.impressionRules(
            for: InAppMessage(
                name: "woot",
                displayContent: .fullscreen(.init(buttons: [], template: .headerBodyMedia))
            )
        )
        #expect(rule == .once)
    }

    @Test
    func testModalMessage() throws {
        let rule = provider.impressionRules(
            for: InAppMessage(
                name: "woot",
                displayContent: .modal(.init(buttons: [], template: .headerBodyMedia))
            )
        )
        #expect(rule == .once)
    }

    @Test
    func testBannerMessage() throws {
        let rule = provider.impressionRules(
            for: InAppMessage(
                name: "woot",
                displayContent: .banner(.init(buttons: [], template: .mediaLeft))
            )
        )
        #expect(rule == .once)
    }

    @Test
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
        #expect(rule == .once)
    }

    @Test
    func testBannerThomas() throws {
        let airshipLayout = """
        {
          "version":1,
          "presentation":{
             "type":"banner",
             "default_placement":{
                "position": {
                  "horizontal": "center",
                  "vertical": "bottom"
                },
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
        #expect(rule == .once)
    }

    @Test
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
        #expect(rule == .interval(1800.0))
    }
}
