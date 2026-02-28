
import Foundation

@testable
import AirshipCore

final class TestURLOpener: URLOpenerProtocol, @unchecked Sendable {
    var returnValue: Bool = true
    var lastURL: URL? = nil
    var openSettingsCalled: Bool = false
    var lastCompletionHandlerValue: Bool? = nil

    @MainActor
    func openURL(_ url: URL) async -> Bool {
        self.lastURL = url
        return returnValue
    }

    @MainActor
    func openURL(_ url: URL, completionHandler: (@MainActor @Sendable (Bool) -> Void)?) {
        self.lastURL = url
        self.lastCompletionHandlerValue = returnValue
        completionHandler?(returnValue)
    }

    @MainActor
    func openSettings() async -> Bool {
        self.openSettingsCalled = true
        return returnValue
    }
}
