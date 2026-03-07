/* Copyright Airship and Contributors */

import Testing

@testable
import AirshipNotificationServiceExtension
import UserNotifications

@Suite("Media Attachment Payload")
struct MediaAttachmentPayloadTest {
    
    @Test
    func airshipEmptyPayload() {
        let payload = decodeFrom(source: [:])
        #expect(payload == nil)
    }
    
    @Test
    func airshipURLPayloads() {
        //invalid payload
        let decoded = decodeFrom(source: [ "url": [:] ])
        #expect(decoded == nil)
        
        // Test valid contents of the url when it is an empty array
        var payload = decodeFrom(source: [ "url": [] ])
        #expect(payload != nil)
        #expect(0 == payload?.media.count)
        
        // Airship payload
        payload = decodeFrom(source: [ "url": "https://sample.url" ])
        #expect(payload != nil)
        #expect(1 == payload?.media.count)
        #expect("https://sample.url" == payload?.media.first?.url.absoluteString)
        
        // Test contents of the url when it is an array with valid urls
        payload = decodeFrom(source: [ "url": ["https://sample.url", "http://sample1.url"] ])
        #expect(payload != nil)
        #expect(2 == payload?.media.count)
        #expect("https://sample.url" == payload?.media.first?.url.absoluteString)
        #expect("http://sample1.url" == payload?.media.last?.url.absoluteString)
    }
    
    @Test
    func airshipURLSPayloads() {
        //invalid
        #expect(decodeFrom(source: ["urls": [:]]) == nil)
        
        // Test contents of the url when it is an array with invalid urls
        var payload = decodeFrom(source: ["urls": [1]])
        #expect(payload == nil)
        
        // VALID PAYLOADS
        // "url" key is ignored if "urls" is present
        payload = decodeFrom(source: [
            "url": "https://test.url",
            "urls": []
        ])
        #expect(payload != nil)
        #expect(0 == payload?.media.count)
        
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
        
        #expect("http://sample1.url" == payload?.media.first?.url.absoluteString)
        #expect("sample-1-id" == payload?.media.first?.urldID)
        #expect("http://sample2.url" == payload?.media.last?.url.absoluteString)
        #expect("sample-2-id" == payload?.media.last?.urldID)
    }
    
    @Test
    func airshipOptionsPayloads() {
        // NOT VALID PAYLOADS
        #expect(
            decodeFrom(
                source: [
                    "url": "https://test.ur",
                    "options": []
                ]
            ) == nil
        )
        
        // VALID PAYLOADS
        let payload = decodeFrom(source: [
            "url": "https://test.ur",
            "options": [:]
        ])
        #expect(payload != nil)
        #expect(payload?.options != nil)
        #expect(payload?.options.crop == nil)
        #expect(payload?.options.hidden == nil)
        #expect(payload?.options.time == nil)
    }
    
    @Test
    func airshipCropOptionsPayloads() {
        // NOT VALID PAYLOADS
        var payload = decodeFrom(source: [
            "url": "https://test.ur",
            "options": [ "crop": "" ]
        ])
        #expect(payload == nil)
        
        // Empty crop dictionary
        payload = decodeFrom(source: [
            "url": "https://test.ur",
            "options": [ "crop": [:] ]
        ])
        #expect(payload == nil)
        
        // Missing crop option
        payload = decodeFrom(source: [
            "url": "https://test.ur",
            "options": [ "crop": [
                "y": 0,
                "width": 0.5,
                "height": 1
            ] ]
        ])
        #expect(payload == nil)
        
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
        #expect(payload == nil)
        
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
        #expect(payload != nil)
        
        let generatedCrop = payload?.options.generateNotificationAttachmentOptions(hideThumbnail: false)[UNNotificationAttachmentOptionsThumbnailClippingRectKey] as? [String: Double]
        #expect(1 == generatedCrop?["X"])
        #expect(1 == generatedCrop?["Y"])
        #expect(0.5 == generatedCrop?["Width"])
        #expect(1 == generatedCrop?["Height"])
    }
    
    @Test
    func airshipTimeOptionPayloads() {
        // NOT VALID PAYLOADS
        #expect(
            decodeFrom(
                source: [
                    "url": "https://test.ur",
                    "options": ["time": ""]
                ]
            ) == nil
        )
        
        // VALID PAYLOADS
        let payload = decodeFrom(source: [
            "url": "https://test.ur",
            "options": [
                "time": 1.0
            ]
            
        ])
        #expect(payload != nil)
        #expect(1 == payload?.options.time)
        #expect(1 == payload?.options.generateNotificationAttachmentOptions(hideThumbnail: false)[UNNotificationAttachmentOptionsThumbnailTimeKey] as? Double)
    }
    
    @Test
    func airshipHiddenOptionPayloads() {
        // NOT VALID PAYLOADS
        #expect(
            decodeFrom(
                source: [
                    "url": "https://test.ur",
                    "options": ["hidden": ""]
                ]
            ) == nil
        )
        
        // VALID PAYLOADS
        let payload = decodeFrom(source: [
            "url": "https://test.ur",
            "options": [
                "hidden": true
            ]
            
        ])
        #expect(payload != nil)
        #expect(true == payload?.options.hidden)
        #expect(true == payload?.options.generateNotificationAttachmentOptions(hideThumbnail: false)[UNNotificationAttachmentOptionsThumbnailHiddenKey] as? Bool)
    }
    
    @Test
    func airshipContentPayloads() {
        // NOT VALID PAYLOADS
        #expect(
            decodeFrom(
                source: [
                    "url": "https://test.ur",
                    "content": ""
                ]
            )
            == nil
        )
        
        // non-valid content
        #expect(
            decodeFrom(
                source: [
                    "url": "https://test.ur",
                    "content": [ "body": [:] ]
                ]
            )
            == nil
        )
        
        // VALID PAYLOADS
        // empty content
        var payload = decodeFrom(source: [
            "url": "https://test.ur",
            "content": [:]
        ])
        #expect(payload != nil)
        #expect(payload?.textContent != nil)
        #expect(payload?.textContent?.title == nil)
        #expect(payload?.textContent?.subtitle == nil)
        #expect(payload?.textContent?.body == nil)
        
        // minimal content
        payload = decodeFrom(source: [
            "url": "https://test.ur",
            "content": ["title" : "sample title" ]
        ])
        #expect(payload != nil)
        #expect(payload?.textContent != nil)
        #expect("sample title" == payload?.textContent?.title)
        #expect(payload?.textContent?.subtitle == nil)
        #expect(payload?.textContent?.body == nil)
        
        // complete content
        payload = decodeFrom(source: [
            "url": "https://test.ur",
            "content": [
                "title" : "sample title",
                "subtitle": "sample subtitle",
                "body": "sample body"
            ]
        ])
        #expect(payload != nil)
        #expect(payload?.textContent != nil)
        #expect("sample title" == payload?.textContent?.title)
        #expect("sample subtitle" == payload?.textContent?.subtitle)
        #expect("sample body" == payload?.textContent?.body)
    }
    
    @Test
    func airshipThumbnailIDPayloads() {
        // NOT VALID PAYLOADS
        #expect(
            decodeFrom(
                source: [
                    "url": "https://test.ur",
                    "thumbnail_id": 1
                ]
            )
            == nil
        )
        
        // VALID PAYLOADS
        let payload = decodeFrom(source: [
            "url": "https://test.ur",
            "thumbnail_id": "test-thumbnail"
        ])
        
        #expect(payload != nil)
        #expect("test-thumbnail" == payload?.thumbnailID)
    }
    
    @Test
    func accengageThumbnailIDPayloads() {
        // NOT VALID PAYLOADS
        #expect(
            decodeFrom(
                source: [
                    "a4sid": "id",
                    "url": "https://test.ur",
                    "thumbnail_id": 1
                ]
            )
            == nil
        )
        
        // VALID PAYLOADS
        let payload = decodeFrom(source: [
            "a4sid": "id",
            "url": "https://test.ur",
            "thumbnail_id": "test-thumbnail"
        ])
        
        #expect(payload != nil)
        #expect("test-thumbnail" == payload?.thumbnailID)
    }
    
    private func decodeFrom(source: [String: Any]) -> MediaAttachmentPayload? {
        let data = try! JSONSerialization.data(withJSONObject: source)
        return try? JSONDecoder().decode(MediaAttachmentPayload.self, from: data)
    }
}
