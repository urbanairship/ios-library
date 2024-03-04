/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipNotificationServiceExtension

final class UANotificationServiceExtensionTests: XCTestCase {
    let subject = UANotificationServiceExtension()
    
    func testEmptyContent() {
        let content = UNNotificationContent()
        let request = UNNotificationRequest(identifier: "identifier", content: content, trigger: nil)
        let expectation = expectation(description: "delivery")
        
        subject.didReceive(request) { deliveredContent in
            XCTAssertEqual(0, deliveredContent.attachments.count)
            XCTAssertNil(deliveredContent.badge)
            XCTAssertNil(deliveredContent.sound)
            XCTAssertEqual("", deliveredContent.body)
            XCTAssertEqual("", deliveredContent.title)
            XCTAssertEqual("", deliveredContent.subtitle)
            XCTAssertEqual("", deliveredContent.categoryIdentifier)
            XCTAssertEqual("", deliveredContent.launchImageName)
            XCTAssertEqual("", deliveredContent.threadIdentifier)
            XCTAssertEqual(0, deliveredContent.userInfo.count)
            XCTAssertEqual("", deliveredContent.summaryArgument)
            XCTAssertEqual(0, deliveredContent.summaryArgumentCount)
            XCTAssertNil(deliveredContent.targetContentIdentifier)
            expectation.fulfill()
        }
        
        self.wait(for: [expectation], timeout: 5)
    }
    
    func testSampleContent() throws {
        
        let fileUrl = try XCTUnwrap(Bundle(for: self.classForCoder).url(forResource: "airship", withExtension: "jpg"))
        
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
        let expectation = self.expectation(description: "delivery")
        
        self.subject.didReceive(request) { deliveredContent in
            XCTAssertEqual(1, deliveredContent.attachments.count)
            let attachment = deliveredContent.attachments[0]
            
            XCTAssertNotNil(attachment.identifier)
            XCTAssertNotNil(attachment.url)
            XCTAssert(FileManager.default.contentsEqual(atPath: attachment.url.path, andPath: fileUrl.path))
            XCTAssertEqual("public.jpeg", attachment.type)
            
            XCTAssertNil(deliveredContent.badge)
            XCTAssertNil(deliveredContent.sound)
            XCTAssertNil(deliveredContent.targetContentIdentifier)
            XCTAssertEqual("Moustache Twirl", deliveredContent.title)
            XCTAssertEqual("The saga of a bendy stache.", deliveredContent.subtitle)
            XCTAssertEqual("Have you ever seen a moustache like this?!", deliveredContent.body)
            XCTAssertEqual("news", deliveredContent.categoryIdentifier)
            XCTAssertEqual("", deliveredContent.launchImageName)
            XCTAssertEqual("", deliveredContent.threadIdentifier)
            XCTAssertEqual("", deliveredContent.summaryArgument)
            XCTAssertEqual(0, deliveredContent.summaryArgumentCount)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5)
    }
}
