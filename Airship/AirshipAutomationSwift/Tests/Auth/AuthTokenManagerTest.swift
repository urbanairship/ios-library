/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipAutomationSwift
@testable import AirshipCore

final class AuthTokenManagerTest: XCTestCase {
    
    var client = TestAuthTokenAPIClient()
    var channel = TestChannel()
    var channelID = "channel ID"
    var testDate = UATestDate(offset: 0, dateOverride: Date.now)
    var manager: AuthTokenManager?
    
    override func setUpWithError() throws {
        self.channel.identifier = "channel ID"
        self.manager = AuthTokenManager(
            apiClient: self.client,
            channel: channel,
            date: self.testDate)
    }
    
    func testTokenWithCompletionHandler() async throws {
        self.client.handler = { channelId in
            let authToken = AuthToken(
                channelID: channelId,
                token: "my token",
                expiration: NSDate.distantFuture)
            return AirshipHTTPResponse(
                result: authToken,
                statusCode: 200,
                headers: [:])
        }
        let token = await self.manager?.token()
        XCTAssertEqual("my token", token)
    }
    
    func testTokenWithNilChannelID() async {
        self.channel.identifier = nil
        let token = await self.manager?.token()
        XCTAssertNil(token)
    }
    
    func testTokenWithCachesTokens() async {
        self.client.handler = { channelId in
            let authToken = AuthToken(
                channelID: channelId,
                token: "token",
                expiration: NSDate.distantFuture)
            return AirshipHTTPResponse(
                result: authToken,
                statusCode: 200,
                headers: [:])
        }
        let firstToken = await self.manager?.token()
        
        self.client.handler = { channelId in
            let authToken = AuthToken(
                channelID: channelId,
                token: "some other token",
                expiration: NSDate.distantFuture)
            return AirshipHTTPResponse(
                result: authToken,
                statusCode: 200,
                headers: [:])
        }
        let secondToken = await self.manager?.token()
        
        XCTAssertEqual(firstToken, secondToken)
    }
    
    
    func testTokenWithError() async {
        self.client.error = NSError(
            domain: NSCocoaErrorDomain,
            code: 0)
        let token = await self.manager?.token()
        XCTAssertNil(token)
    }
    
    
    func testTokenWithCachedTokenExpired() async {
        self.client.handler = { channelId in
            let authToken = AuthToken(
                channelID: channelId,
                token: "token",
                expiration: Date(
                    timeInterval: 24 * 60 * 60,
                    since: self.testDate.now))
            return AirshipHTTPResponse(
                result: authToken,
                statusCode: 200,
                headers: [:])
        }

        let firstToken = await self.manager?.token()
        
        // Invalidate the cache "naturally"
        self.testDate.dateOverride = Date(
            timeInterval: 24 * 60 * 60 * 2,
            since: self.testDate.now)
        
        // On the subsequent lookup the token should be re-fetched
        self.client.handler = { channelId in
            let authToken = AuthToken(
                channelID: channelId,
                token: "some other token",
                expiration: NSDate.distantFuture)
            return AirshipHTTPResponse(
                result: authToken,
                statusCode: 200,
                headers: [:])
        }
        
        let secondToken = await self.manager?.token()
        
        XCTAssertNotEqual(firstToken, secondToken);
    }
    
    
    func testExpireToken() async {
        self.client.handler = { channelId in
            let authToken = AuthToken(
                channelID: channelId,
                token: "token",
                expiration: NSDate.distantFuture)
            return AirshipHTTPResponse(
                result: authToken,
                statusCode: 200,
                headers: [:])
        }
        
        let firstToken = await self.manager?.token()
        XCTAssertNotNil(firstToken)
        
        // Invalidate the token manually
        self.manager?.expireToken(firstToken!)
        
        // On the subsequent lookup the token should be re-fetched
        self.client.handler = { channelId in
            let authToken = AuthToken(
                channelID: channelId,
                token: "some other token",
                expiration: NSDate.distantFuture)
            return AirshipHTTPResponse(
                result: authToken,
                statusCode: 200,
                headers: [:])
        }
        
        let secondToken = await self.manager?.token()
        XCTAssertNotNil(secondToken)
        XCTAssertNotEqual(firstToken, secondToken)
    }
}

