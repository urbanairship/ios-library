/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore
import WebKit

final class InAppMessageNativeBridgeExtensionTest: XCTestCase {

    func testExtras() async throws {
        let message = InAppMessage(
            name: "some name",
            displayContent: .custom("custom"),
            extras: ["cool": "value"]
        )

        let jsProtocol = TestJSProtocol()
        let bridgeExtension = InAppMessageNativeBridgeExtension(message: message)
        await bridgeExtension.extendJavaScriptEnvironment(jsProtocol, webView: WKWebView())


        XCTAssertEqual(jsProtocol.getters, ["getMessageExtras": message.extras])
    }

    func testExtrasWrongType() async throws {
        let message = InAppMessage(
            name: "some name",
            displayContent: .custom("custom"),
            extras: "value"
        )

        let jsProtocol = TestJSProtocol()
        let bridgeExtension = InAppMessageNativeBridgeExtension(message: message)
        await bridgeExtension.extendJavaScriptEnvironment(jsProtocol, webView: WKWebView())


        XCTAssertEqual(jsProtocol.getters, ["getMessageExtras": .object([:])])
    }


    func testExtrasMissing() async throws {
        let message = InAppMessage(
            name: "some name",
            displayContent: .custom(.string("custom")),
            extras: nil
        )

        let jsProtocol = TestJSProtocol()
        let bridgeExtension = InAppMessageNativeBridgeExtension(message: message)
        await bridgeExtension.extendJavaScriptEnvironment(jsProtocol, webView: WKWebView())


        XCTAssertEqual(jsProtocol.getters, ["getMessageExtras": .object([:])])
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
