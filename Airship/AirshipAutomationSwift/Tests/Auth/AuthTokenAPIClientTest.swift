/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore
@testable import AirshipAutomationSwift

final class AuthTokenAPIClientTest: AirshipBaseTest {
    
    var client: AuthTokenAPIClient?
    var session = TestAirshipRequestSession()
    
    override func setUpWithError() throws {
        self.client = AuthTokenAPIClient(
            config: self.config,
            session: self.session)
    }
    
    func testTokenWithChannelID() async throws {
        self.session.data = try JSONUtils.data([
            "token": "abc123",
            "expires_in": 12345
        ])
        self.session.response = HTTPURLResponse(
            url: URL(string: "https://www.linkedin.com/")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)
        let token = try await self.client?.token(
            withChannelID: "channel ID")
        XCTAssertNotNil(token)
        
        let request = try XCTUnwrap(self.session.lastRequest)
        
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.url!.absoluteString, "\(self.config.deviceAPIURL!)/api/auth/device")
        XCTAssertEqual(request.headers["X-UA-Channel-ID"], "channel ID")
        XCTAssertEqual(request.headers["X-UA-App-Key"], self.config.appKey)
        XCTAssertEqual(request.headers["Accept"], "application/vnd.urbanairship+json; version=3;")
    }
    
    func testTokenWithChannelIDMalformedPayload() async throws {
        self.session.data = try JSONUtils.data([
            "not a token": "abc123",
            "expires_in_3_2_1": 12345
        ])
        self.session.response = HTTPURLResponse(
            url: URL(string: "https://www.linkedin.com/")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)
        
        do {
            let _ = try await self.client?.token(
                withChannelID: "channel ID")
            XCTFail("Should throw")
        } catch {
            XCTAssertNotNil(error)
        }
        
    }
    
    func testTokenWithChannelIDClientError() async throws {
        self.session.data = try JSONUtils.data([
            "too": "bad"
        ])
        self.session.response = HTTPURLResponse(
            url: URL(string: "https://www.linkedin.com/")!,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil)
        
        let response = try await self.client?.token(
            withChannelID: "channel ID")
        let unwrapResponse = try XCTUnwrap(response)
        XCTAssertNil(unwrapResponse.result?.token)
        XCTAssertTrue(unwrapResponse.isClientError)
        XCTAssertFalse(unwrapResponse.isSuccess)
    }
}

