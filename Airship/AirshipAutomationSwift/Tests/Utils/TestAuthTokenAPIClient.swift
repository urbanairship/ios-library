/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipAutomationSwift
@testable import AirshipCore

final class TestAuthTokenAPIClient: AuthTokenAPIClientProtocol {
    
    var error: NSError? = nil
    var handler: ((String) async throws -> AirshipHTTPResponse<AuthToken>)?
    
    func token(
        withChannelID channelID: String
    ) async throws -> AirshipHTTPResponse<AuthToken> {
        
        if let error = error {
            throw error
        }
        
        guard let handler = handler else {
            throw AirshipErrors.error("Request block not set")
        }
        
        return try await handler(channelID)
    }
    
}
