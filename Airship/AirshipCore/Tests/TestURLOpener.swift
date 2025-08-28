


@testable
import AirshipCore

final class TestURLOpener: URLOpenerProtocol, @unchecked Sendable {
    var returnValue: Bool = false
    var lastURL: URL? = nil

    func openURL(_ url: URL) async -> Bool {
        self.lastURL = url
        return returnValue
    }
}
