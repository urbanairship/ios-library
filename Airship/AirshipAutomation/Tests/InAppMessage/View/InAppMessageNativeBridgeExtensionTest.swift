/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal)
import AirshipAutomation
import AirshipCore
import WebKit

struct InAppMessageNativeBridgeExtensionTest {

    @Test
    func testExtras() async throws {
        let message = InAppMessage(
            name: "some name",
            displayContent: .custom("custom"),
            extras: ["cool": "value"]
        )

        let jsProtocol = TestJSProtocol()
        let bridgeExtension = InAppMessageNativeBridgeExtension(message: message)
        await bridgeExtension.extendJavaScriptEnvironment(jsProtocol, webView: WKWebView())


        #expect(jsProtocol.getters == ["getMessageExtras": message.extras])
    }

    @Test
    func testExtrasWrongType() async throws {
        let message = InAppMessage(
            name: "some name",
            displayContent: .custom("custom"),
            extras: "value"
        )

        let jsProtocol = TestJSProtocol()
        let bridgeExtension = InAppMessageNativeBridgeExtension(message: message)
        await bridgeExtension.extendJavaScriptEnvironment(jsProtocol, webView: WKWebView())


        #expect(jsProtocol.getters == ["getMessageExtras": .object([:])])
    }


    @Test
    func testExtrasMissing() async throws {
        let message = InAppMessage(
            name: "some name",
            displayContent: .custom(.string("custom")),
            extras: nil
        )

        let jsProtocol = TestJSProtocol()
        let bridgeExtension = InAppMessageNativeBridgeExtension(message: message)
        await bridgeExtension.extendJavaScriptEnvironment(jsProtocol, webView: WKWebView())


        #expect(jsProtocol.getters == ["getMessageExtras": .object([:])])
    }
}


fileprivate final class TestJSProtocol: JavaScriptEnvironmentProtocol, @unchecked Sendable {
    var getters: [String: AirshipJSON] = [:]

    func add(_ getter: String, string: String?) {
        getters[getter] = try! AirshipJSON.wrap(string)
    }
    
    func add(_ getter: String, number: Double?) {
        getters[getter] = try! AirshipJSON.wrap(number)
    }
    
    func add(_ getter: String, dictionary: [AnyHashable : Any]?) {
        getters[getter] = try! AirshipJSON.wrap(dictionary)
    }
    
    func build() async -> String {
        return ""
    }
}
