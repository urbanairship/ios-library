/* Copyright Airship and Contributors */

import Testing

@testable
import AirshipNotificationServiceExtension
import UserNotifications
import Foundation

@Suite("U A Notification Service Extension")
struct UANotificationServiceExtensionTests {
    
    private class BundleFinder {}
    let subject = UANotificationServiceExtension()
    
    @Test
    func emptyContent() async throws {
        // 1. Setup
        let content = UNNotificationContent()
        let request = UNNotificationRequest(
            identifier: "identifier", content: content, trigger: nil
        )
        
        let deliveredContent: UNNotificationContent = try await withCheckedThrowingContinuation { continuation in
            subject.didReceive(request) { result in
                continuation.resume(returning: result)
            }
        }
        
        // 3. Assertions
        #expect(deliveredContent.attachments.isEmpty)
        #expect(deliveredContent.badge == nil)
        #expect(deliveredContent.sound == nil)
        #expect(deliveredContent.body.isEmpty)
        #expect(deliveredContent.title.isEmpty)
        #expect(deliveredContent.subtitle.isEmpty)
        #expect(deliveredContent.categoryIdentifier.isEmpty)
        #expect(deliveredContent.launchImageName.isEmpty)
        #expect(deliveredContent.threadIdentifier.isEmpty)
        #expect(deliveredContent.userInfo.isEmpty)
        #expect(deliveredContent.targetContentIdentifier == nil)
    }
    
    @Test
    func sampleContent() async throws {
        
        let fileUrl = try #require(
            Bundle(for: BundleFinder.self)
                .url(forResource: "airship", withExtension: "jpg")
        )
        
        let content = UNMutableNotificationContent()
        content.body = "oh hi"
        content.categoryIdentifier = "news"
        content.userInfo = [
            "_": "a323385b-010a-401c-93ae-936cb58dff04",
            "apps": [
                "alert": "oh hi",
                "category": "news",
                "mutable-content": true
            ],
            "com.urbanairship.metadata": "eyJ2ZXJzaW9uX2lkIjoxLCJ0aW1lIjoxNTg3NTc2Mzk2NDM1LCJwdXNoX2lkIjoiNmUyNzQ1N2MtZDllNi00MWQ3LWJlZDYtNTAyMTkyNDA0NDI2In0=",
            "com.urbanairship.media_attachment": [
                "url": fileUrl.absoluteString,
                "content": [
                    "title": "Moustache Twirl",
                    "subtitle": "The saga of a bendy stache.",
                    "body": "Have you ever seen a moustache like this?!"
                ],
                "options": [
                    "crop": [
                        "x": 0.25,
                        "y": 0.25,
                        "width": 0.5,
                        "height": 0.5
                    ],
                    "time": 15.0
                ]
            ],
        ]
        
        let request = UNNotificationRequest(identifier: "4B2D08E6-8955-4964-8C15-6F7FEBC0EBB4", content: content, trigger: nil)
        
        let deliveredContent: UNNotificationContent = try await withCheckedThrowingContinuation { continuation in
            subject.didReceive(request) { result in
                continuation.resume(returning: result)
            }
        }
        
        try #require(deliveredContent.attachments.count == 1)
        let attachment = deliveredContent.attachments[0]
        
        
        #expect(FileManager.default.contentsEqual(atPath: attachment.url.path, andPath: fileUrl.path))
        #expect("public.jpeg" == attachment.type)
        
        #expect(deliveredContent.badge == nil)
        #expect(deliveredContent.sound == nil)
        #expect(deliveredContent.targetContentIdentifier == nil)
        #expect("Moustache Twirl" == deliveredContent.title)
        #expect("The saga of a bendy stache." == deliveredContent.subtitle)
        #expect("Have you ever seen a moustache like this?!" == deliveredContent.body)
        #expect("news" == deliveredContent.categoryIdentifier)
        #expect("" == deliveredContent.launchImageName)
        #expect("" == deliveredContent.threadIdentifier)
    }
    
}
