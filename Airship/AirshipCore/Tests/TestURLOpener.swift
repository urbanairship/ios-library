
import Foundation

@testable
import AirshipCore

final class TestURLOpener: URLOpenerProtocol, @unchecked Sendable {
    @MainActor
    var returnValue: Bool = true

    @MainActor
    var lastURL: URL?

    @MainActor
    var lastOpenSettingsCalled: Bool = false

    @MainActor
    func reset() {
        lastURL = nil
        lastOpenSettingsCalled = false
    }

    @MainActor
    func openURL(_ url: URL) async -> Bool {
        lastURL = url
        return returnValue
    }

    @MainActor
    func openURL(_ url: URL, completionHandler: (@MainActor @Sendable (Bool) -> Void)?) {
        lastURL = url
        completionHandler?(returnValue)
    }

    @MainActor
    func openSettings() async -> Bool {
        lastOpenSettingsCalled = true
        return returnValue
    }
}
