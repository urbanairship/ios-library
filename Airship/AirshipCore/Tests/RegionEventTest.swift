/* Copyright Airship and Contributors */

import Testing
@testable import AirshipCore
import Foundation

@Suite struct RegionEventTest {

    private let coordinates: (latitude: Double, longitude: Double) = (45.5200, 122.6819)
    private var validRegionId: String {
        return "".padding(toLength: 255, withPad: "REGION_ID", startingAt: 0)
    }
    private var validSource: String {
        return "".padding(toLength: 255, withPad: "SOURCE", startingAt: 0)
    }

    /**
     * Test region event data directly.
     */
    @Test
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

        #expect(try! AirshipJSON.wrap(expected) == (try! event?.eventBody(stringifyFields: true)))
    }

    /**
     * Test setting a region event ID.
     */
    @Test
    func testSetRegionEventID() {
        var event = RegionEvent(regionID: self.validRegionId, source: self.validSource, boundaryEvent: .enter)
        #expect(self.validRegionId == event?.regionID)

        let invalidRegionId = "".padding(toLength: 256, withPad: "REGION_ID", startingAt: 0)
        event = RegionEvent(regionID: invalidRegionId, source: self.validSource, boundaryEvent: .enter)
        #expect(event == nil, "Region IDs larger than 255 characters should be ignored")

        event = RegionEvent(regionID: "", source: self.validSource, boundaryEvent: .enter)
        #expect(event == nil, "Region IDs less than 1 character should be ignored")
    }

    /**
     * Test setting a region event source.
     */
    @Test
    func testSetSource() {
        var event = RegionEvent(regionID: self.validRegionId, source: self.validSource, boundaryEvent: .enter)
        #expect(event?.source == validSource, "255 character source should be valid")

        let invalidSource = "".padding(toLength: 256, withPad: "source", startingAt: 0)
        event = RegionEvent(regionID: self.validRegionId, source: invalidSource, boundaryEvent: .enter)
        #expect(event == nil, "Sources larger than 255 characters should be ignored")

        event = RegionEvent(regionID: self.validRegionId, source: "", boundaryEvent: .enter)
        #expect(event == nil, "Sources less than 1 character should be ignored")

        event = RegionEvent(regionID: self.validRegionId, source: self.validSource, boundaryEvent: .enter)
        #expect(event?.source == validSource, "255 character source should be valid")
    }

    /**
     * Test creating a region event without a proximity or circular region
     */
    @Test
    func testRegionEvent() {
        let event = RegionEvent(regionID: self.validRegionId, source: self.validSource, boundaryEvent: .enter)

        let expected: [String: Any] = [
            "action": "enter",
            "region_id": "\(self.validRegionId)",
            "source": "\(self.validSource)",
        ]

        #expect(try! AirshipJSON.wrap(expected) == (try! event?.eventBody(stringifyFields: true)))

    }

}
