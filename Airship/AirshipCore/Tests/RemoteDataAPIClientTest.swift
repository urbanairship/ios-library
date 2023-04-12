/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class RemoteDataAPIClientTest: AirshipBaseTest {
    
    var remoteDataAPIClient: RemoteDataAPIClient?
    var testSession: TestAirshipRequestSession?
    var remoteData: [[String : Any]]?
    
    override func setUpWithError() throws {
        
        self.testSession = TestAirshipRequestSession()
        self.remoteDataAPIClient = RemoteDataAPIClient(
            config: self.config,
            session: self.testSession!)
        
        self.remoteData = [
            [
                "type": "test_data_type",
                "timestamp": "2017-01-01T12:00:00",
                "data": [
                    "message_center" :
                        [ "background_color" : "0000FF",
                          "font" : "Comic Sans"
                        ]
                ]
            ]
        ]
    }
    
    func testFetchRemoteData() async throws {
        // Create a successful response
        let responseLastModified = "2017-01-01T12:00:00"
        self.testSession?.data = try createRemoteDataResponseForPayloads(self.remoteData!)
        self.testSession?.response = HTTPURLResponse(
            url: URL(string: "AnyUrl")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [
                "Last-Modified": responseLastModified
            ])
        
        // Make call
        let response = try await self.remoteDataAPIClient?.fetchRemoteData(
            locale: NSLocale.current,
            randomValue: 456,
            lastModified: nil)
        
        XCTAssertNotNil(response)
        XCTAssertEqual(1, response?.result?.payloads?.count)
        
        
        let remoteData = response?.result?.payloads?.first as? RemoteDataPayload
        XCTAssertEqual(self.remoteData?[0]["type"] as? String, remoteData?.type)
        XCTAssertEqual(self.remoteData?[0]["data"] as! [String : [String : String]] , remoteData?.data as! [String : [String : String]])
        
        var timestamp: String? = nil
        if let aTimestamp = remoteData?.timestamp {
            timestamp = AirshipUtils.isoDateFormatterUTCWithDelimiter().string(from: aTimestamp)
        }
        XCTAssertEqual(self.remoteData?[0]["timestamp"] as? String, timestamp)
        
        XCTAssertEqual(responseLastModified, response?.result?.lastModified)
        
        let expectedMetadata = [
            "url": self.testSession?.lastRequest?.url?.absoluteString,
            "last_modified": responseLastModified
        ]
        
        XCTAssertEqual(expectedMetadata, response?.result?.metadata as! [String : String])
        XCTAssertEqual(expectedMetadata, remoteData?.metadata as! [String : String])
        
        
        let expected = "https://remote-data.urbanairship.com/api/remote-data/app/\(config.appKey)/ios?sdk_version=\(AirshipVersion.get())&language=\(NSLocale.current.languageCode!)&country=\(NSLocale.current.regionCode!)&random_value=\(NSNumber(value: 456))"
        
        XCTAssertEqual(expected, self.testSession?.lastRequest?.url?.absoluteString)
        
    }
    
    func testFetchRemoteData304() async throws {
        let lastModified = "2017-01-01T12:00:00"
        self.testSession?.response = HTTPURLResponse(
            url: URL(string: "AnyUrl")!,
            statusCode: 304,
            httpVersion: nil,
            headerFields: [
                "Last-Modified": lastModified
            ]
        )
        

        let result = try await self.remoteDataAPIClient?.fetchRemoteData(
            locale: NSLocale.current,
            randomValue: 777,
            lastModified: lastModified
        )

        XCTAssertEqual(result?.statusCode, 304)
    }
    
    /// Test refresh the remote data when no remote data returned from cloud
    func testFetchRemoteDataNoPayloads() async throws {
        let responseLastModified = "2017-01-01T12:00:00"
        self.testSession?.data = try createRemoteDataResponseForPayloads([])
        self.testSession?.response = HTTPURLResponse(
            url: URL(string: "AnyUrl")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [
                "Last-Modified": responseLastModified
            ])
        
        // Make call
        let response = try await self.remoteDataAPIClient?.fetchRemoteData(
            locale: NSLocale.current,
            randomValue: 333,
            lastModified: nil)
        
        XCTAssertEqual(200, response?.statusCode)
        XCTAssertEqual(responseLastModified, response?.result?.lastModified)
        XCTAssertEqual([], response?.result?.payloads)
    }
    
    func testVersion() async throws {
        let responseLastModified = "2017-01-01T12:00:00"
        self.testSession?.data = try createRemoteDataResponseForPayloads(self.remoteData!)
        self.testSession?.response = HTTPURLResponse(
            url: URL(string: "AnyUrl")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [
                "Last-Modified": responseLastModified
            ])
        
        
        // Make call
        _ = try await self.remoteDataAPIClient?.fetchRemoteData(
            locale: NSLocale.current,
            randomValue: 444,
            lastModified: nil)
        
        let expectedVersionQuery = "sdk_version=\(AirshipVersion.get())"
        
        let request = self.testSession?.lastRequest
        let queryComponents = request?.url?.query?.components(separatedBy: "&")
        XCTAssertTrue(queryComponents!.contains(expectedVersionQuery))
    }
    
    func testLocale() async throws {
        let locale = NSLocale(localeIdentifier: "en-01")
        let responseLastModified = "2017-01-01T12:00:00"
        self.testSession?.data = try createRemoteDataResponseForPayloads(self.remoteData!)
        self.testSession?.response = HTTPURLResponse(
            url: URL(string: "AnyUrl")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [
                "Last-Modified": responseLastModified
            ])
        
        // Make call
        _ = try await self.remoteDataAPIClient?.fetchRemoteData(
            locale: locale as Locale,
            randomValue: 555,
            lastModified: nil)
        
        
        let expectedLanguageQuery = "language=en"
        let expectedCountryQuery = "country=01"
        
        let request = self.testSession?.lastRequest
        let queryComponents = request?.url?.query?.components(separatedBy: "&")
        XCTAssertTrue(queryComponents!.contains(expectedLanguageQuery))
        XCTAssertTrue(queryComponents!.contains(expectedCountryQuery))
    }
    
    func testLocaleMissingCountry() async throws {
        let locale = NSLocale(localeIdentifier: "en")
        let responseLastModified = "2017-01-01T12:00:00"
        self.testSession?.data = try createRemoteDataResponseForPayloads(self.remoteData!)
        self.testSession?.response = HTTPURLResponse(
            url: URL(string: "AnyUrl")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [
                "Last-Modified": responseLastModified
            ])
        
        // Make call
        _ = try await self.remoteDataAPIClient?.fetchRemoteData(
            locale: locale as Locale,
            randomValue: 666,
            lastModified: nil)
        
        let expectedLanguageQuery = "language=en"
        
        let request = self.testSession?.lastRequest
        let queryComponents = request?.url?.query?.components(separatedBy: "&")
        XCTAssertTrue(queryComponents!.contains(expectedLanguageQuery))
        XCTAssertFalse(request!.url!.query!.contains("country="))
    }
    
    func createRemoteDataResponseForPayloads(_ payloads: [Any]) throws -> Data {
        let responseDict: [String: Any] = [ "ok" : true,
                                            "payloads" : payloads
        ]
        
        let remoteData = try JSONUtils.data(
            responseDict,
            options: .prettyPrinted)
        
        return remoteData
    }
    
}
