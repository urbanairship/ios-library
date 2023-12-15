/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class RegionEventTest: XCTestCase {
    
    private var coordinates: (latitude: Double, longitude: Double) = (45.5200, 122.6819)
    private var validRegionId: String {
        return "".padding(toLength: 255, withPad: "REGION_ID", startingAt: 0)
    }
    private var validSource: String {
        return "".padding(toLength: 255, withPad: "SOURCE", startingAt: 0)
    }
    
    /**
     * Test region event data directly.
     */
    func testRegionEventData() {
        let circular = CircularRegion(radius: 11, latitude: coordinates.latitude, longitude: coordinates.longitude)
        let proximity = ProximityRegion(proximityID: "proximity_id", major: 1, minor: 11, rssi: -59,
                                        latitude: coordinates.latitude, longitude: coordinates.longitude)
        let event = RegionEvent(regionID: "region_id", source: "source", boundaryEvent: .enter, circularRegion: circular, proximityRegion: proximity)
        
        let expected: [String: Any] = [
            "action": "enter",
            "region_id": "region_id",
            "source": "source",
            "circular_region": [
                "latitude": "45.5200000",
                "longitude": "122.6819000",
                "radius": "11.0"
            ],
            "proximity": [
                "minor": 11,
                "rssi": -59,
                "major": 1,
                "proximity_id": "proximity_id",
                "latitude": "45.5200000",
                "longitude": "122.6819000"
            ]
        ]
        
        XCTAssertEqual(expected.toNsDictionary(), event?.data.toNsDictionary())
    }
    
    /**
     * Test setting a region event ID.
     */
    func testSetRegionEventID() {
        var event = RegionEvent(regionID: self.validRegionId, source: self.validSource, boundaryEvent: .enter)
        XCTAssertEqual(self.validRegionId, event?.regionID)
        
        let invalidRegionId = "".padding(toLength: 256, withPad: "REGION_ID", startingAt: 0)
        event = RegionEvent(regionID: invalidRegionId, source: self.validSource, boundaryEvent: .enter)
        XCTAssertNil(event, "Region IDs larger than 255 characters should be ignored")
        
        event = RegionEvent(regionID: "", source: self.validSource, boundaryEvent: .enter)
        XCTAssertNil(event, "Region IDs less than 1 character should be ignored")
    }
    
    /**
     * Test setting a region event source.
     */
    func testSetSource() {
        var event = RegionEvent(regionID: self.validRegionId, source: self.validSource, boundaryEvent: .enter)
        XCTAssertEqual(event?.source, validSource, "255 character source should be valid")

        let invalidSource = "".padding(toLength: 256, withPad: "source", startingAt: 0)
        event = RegionEvent(regionID: self.validRegionId, source: invalidSource, boundaryEvent: .enter)
        XCTAssertNil(event, "Sources larger than 255 characters should be ignored")

        event = RegionEvent(regionID: self.validRegionId, source: "", boundaryEvent: .enter)
        XCTAssertNil(event, "Sources less than 1 character should be ignored")

        event = RegionEvent(regionID: self.validRegionId, source: self.validSource, boundaryEvent: .enter)
        XCTAssertEqual(event?.source, validSource, "255 character source should be valid")
    }
    
    /**
     * Test creating a region event without a proximity or circular region
     */
    func testRegionEvent() {
        let event = RegionEvent(regionID: self.validRegionId, source: self.validSource, boundaryEvent: .enter)
        
        XCTAssertEqual(validRegionId, event?.data["region_id"] as! String, "Unexpected region id.")
        XCTAssertEqual(validSource, event?.data["source"] as! String, "Unexpected region source.")
        XCTAssertEqual("enter", event?.data["action"] as! String, "Unexpected boundary event.")
    }
    
    /**
     * Test the event is high priority
     */
    func testHighPriority() {
        let event = RegionEvent(regionID: "id", source: "source", boundaryEvent: .enter)
        XCTAssertEqual(event?.priority, .high)
    }
}
