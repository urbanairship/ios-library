/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipNotificationServiceExtension

final class MediaAttachmentPayloadTest: XCTestCase {
    
    func testAirshipEmptyPayload() {
        let payload = decodeFrom(source: [:])
        XCTAssertNil(payload)
    }
    
    func testAirshipURLPayloads() {
        //invalid payload
        XCTAssertNil(decodeFrom(source: [ "url": [:] ]))
        
        // Test valid contents of the url when it is an empty array
        var payload = decodeFrom(source: [ "url": [] ])
        XCTAssertNotNil(payload)
        XCTAssertEqual(0, payload?.media.count)
        
        // Airship payload
        payload = decodeFrom(source: [ "url": "https://sample.url" ])
        XCTAssertNotNil(payload)
        XCTAssertEqual(1, payload?.media.count)
        XCTAssertEqual("https://sample.url", payload?.media.first?.url.absoluteString)
        
        // Test contents of the url when it is an array with valid urls
        payload = decodeFrom(source: [ "url": ["https://sample.url", "http://sample1.url"] ])
        XCTAssertNotNil(payload)
        XCTAssertEqual(2, payload?.media.count)
        XCTAssertEqual("https://sample.url", payload?.media.first?.url.absoluteString)
        XCTAssertEqual("http://sample1.url", payload?.media.last?.url.absoluteString)
    }
    
    func testAirshipURLSPayloads() {
        //invalid
        XCTAssertNil(decodeFrom(source: ["urls": [:]]))
        
        // Test contents of the url when it is an array with invalid urls
        var payload = decodeFrom(source: ["urls": [1]])
        XCTAssertNil(payload)
        
        // VALID PAYLOADS
        // "url" key is ignored if "urls" is present
        payload = decodeFrom(source: [
            "url": "https://test.url",
            "urls": []
        ])
        XCTAssertNotNil(payload)
        XCTAssertEqual(0, payload?.media.count)
        
        // Test contents of the url when it is an array with valid urls
        payload = decodeFrom(source: [
            "urls": [
                [
                    "url": "http://sample1.url",
                    "url_id": "sample-1-id"
                ],
                [
                    "url": "http://sample2.url",
                    "url_id": "sample-2-id"
                ],
            ]
        ])
        
        XCTAssertEqual("http://sample1.url", payload?.media.first?.url.absoluteString)
        XCTAssertEqual("sample-1-id", payload?.media.first?.urldID)
        XCTAssertEqual("http://sample2.url", payload?.media.last?.url.absoluteString)
        XCTAssertEqual("sample-2-id", payload?.media.last?.urldID)
    }
    
    func testAirshipOptionsPayloads() {
        // NOT VALID PAYLOADS
        XCTAssertNil(decodeFrom(source: [
            "url": "https://test.ur",
            "options": []
        ]))
        
        // VALID PAYLOADS
        let payload = decodeFrom(source: [
            "url": "https://test.ur",
            "options": [:]
        ])
        XCTAssertNotNil(payload)
        XCTAssertNotNil(payload?.options)
        XCTAssertNil(payload?.options.crop)
        XCTAssertNil(payload?.options.hidden)
        XCTAssertNil(payload?.options.time)
    }
    
    func testAirshipCropOptionsPayloads() {
        // NOT VALID PAYLOADS
        var payload = decodeFrom(source: [
            "url": "https://test.ur",
            "options": [ "crop": "" ]
        ])
        XCTAssertNil(payload)
        
        // Empty crop dictionary
        payload = decodeFrom(source: [
            "url": "https://test.ur",
            "options": [ "crop": [:] ]
        ])
        XCTAssertNil(payload)
        
        // Missing crop option
        payload = decodeFrom(source: [
            "url": "https://test.ur",
            "options": [ "crop": [
                "y": 0,
                "width": 0.5,
                "height": 1
            ] ]
        ])
        XCTAssertNil(payload)
        
        // Non-valid crop option
        payload = decodeFrom(source: [
            "url": "https://test.ur",
            "options": [ "crop": [
                "x": 10,
                "y": 0,
                "width": 0.5,
                "height": 1
            ] ]
        ])
        XCTAssertNil(payload)
        
        // valid crop options
        payload = decodeFrom(source: [
            "url": "https://test.ur",
            "options": [ "crop": [
                "x": 1,
                "y": 1,
                "width": 0.5,
                "height": 1
            ] ]
        ])
        XCTAssertNotNil(payload)
        
        let generatedCrop = payload?.options.generateNotificationAttachmentOptions(hideThumbnail: false)[UNNotificationAttachmentOptionsThumbnailClippingRectKey] as? [String: Double]
        XCTAssertEqual(1, generatedCrop?["X"])
        XCTAssertEqual(1, generatedCrop?["Y"])
        XCTAssertEqual(0.5, generatedCrop?["Width"])
        XCTAssertEqual(1, generatedCrop?["Height"])
    }
    
    func testAirshipTimeOptionPayloads() {
        // NOT VALID PAYLOADS
        XCTAssertNil(decodeFrom(source: [
            "url": "https://test.ur",
            "options": ["time": ""]
        ]))
        
        // VALID PAYLOADS
        let payload = decodeFrom(source: [
            "url": "https://test.ur",
            "options": [
                "time": 1.0
            ]
            
        ])
        XCTAssertNotNil(payload)
        XCTAssertEqual(1, payload?.options.time)
        XCTAssertEqual(1, payload?.options.generateNotificationAttachmentOptions(hideThumbnail: false)[UNNotificationAttachmentOptionsThumbnailTimeKey] as? Double)
    }
    
    func testAirshipHiddenOptionPayloads() {
        // NOT VALID PAYLOADS
        XCTAssertNil(decodeFrom(source: [
            "url": "https://test.ur",
            "options": ["hidden": ""]
        ]))
        
        // VALID PAYLOADS
        let payload = decodeFrom(source: [
            "url": "https://test.ur",
            "options": [
                "hidden": true
            ]
            
        ])
        XCTAssertNotNil(payload)
        XCTAssertEqual(true, payload?.options.hidden)
        XCTAssertEqual(true, payload?.options.generateNotificationAttachmentOptions(hideThumbnail: false)[UNNotificationAttachmentOptionsThumbnailHiddenKey] as? Bool)
    }
    
    func testAirshipContentPayloads() {
        // NOT VALID PAYLOADS
        XCTAssertNil(decodeFrom(source: [
            "url": "https://test.ur",
            "content": ""
        ]))
        
        // non-valid content
        XCTAssertNil(decodeFrom(source: [
            "url": "https://test.ur",
            "content": [ "body": [:] ]
        ]))
        
        // VALID PAYLOADS
        // empty content
        var payload = decodeFrom(source: [
            "url": "https://test.ur",
            "content": [:]
        ])
        XCTAssertNotNil(payload)
        XCTAssertNotNil(payload?.textContent)
        XCTAssertNil(payload?.textContent?.title)
        XCTAssertNil(payload?.textContent?.subtitle)
        XCTAssertNil(payload?.textContent?.body)
        
        // minimal content
        payload = decodeFrom(source: [
            "url": "https://test.ur",
            "content": ["title" : "sample title" ]
        ])
        XCTAssertNotNil(payload)
        XCTAssertNotNil(payload?.textContent)
        XCTAssertEqual("sample title", payload?.textContent?.title)
        XCTAssertNil(payload?.textContent?.subtitle)
        XCTAssertNil(payload?.textContent?.body)
        
        // complete content
        payload = decodeFrom(source: [
            "url": "https://test.ur",
            "content": [
                "title" : "sample title",
                "subtitle": "sample subtitle",
                "body": "sample body"
            ]
        ])
        XCTAssertNotNil(payload)
        XCTAssertNotNil(payload?.textContent)
        XCTAssertEqual("sample title", payload?.textContent?.title)
        XCTAssertEqual("sample subtitle", payload?.textContent?.subtitle)
        XCTAssertEqual("sample body", payload?.textContent?.body)
    }
    
    func testAirshipThumbnailIDPayloads() {
        // NOT VALID PAYLOADS
        XCTAssertNil(decodeFrom(source: [
            "url": "https://test.ur",
            "thumbnail_id": 1
        ]))
        
        // VALID PAYLOADS
        let payload = decodeFrom(source: [
            "url": "https://test.ur",
            "thumbnail_id": "test-thumbnail"
        ])
        
        XCTAssertNotNil(payload)
        XCTAssertEqual("test-thumbnail", payload?.thumbnailID)
    }
    
    func testAccengageThumbnailIDPayloads() {
        // NOT VALID PAYLOADS
        XCTAssertNil(decodeFrom(source: [
            "a4sid": "id",
            "url": "https://test.ur",
            "thumbnail_id": 1
        ]))
        
        // VALID PAYLOADS
        let payload = decodeFrom(source: [
            "a4sid": "id",
            "url": "https://test.ur",
            "thumbnail_id": "test-thumbnail"
        ])
        
        XCTAssertNotNil(payload)
        XCTAssertEqual("test-thumbnail", payload?.thumbnailID)
    }
    
    private func decodeFrom(source: [String: Any]) -> MediaAttachmentPayload? {
        let data = try! JSONSerialization.data(withJSONObject: source)
        return try? JSONDecoder().decode(MediaAttachmentPayload.self, from: data)
    }
}
