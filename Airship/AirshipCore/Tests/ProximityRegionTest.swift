/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class ProximityRegionTest: XCTestCase {
    
    private var defaultRegionId: String {
        return "".padding(toLength: 255, withPad: "PROXIMITY_ID", startingAt: 0)
    }
    
    /**
     * Test creating a proximity region with a valid proximity ID major and minor
     */
    func testCreateValidProximityRegion() {
        let region = ProximityRegion(proximityID: defaultRegionId, major: 1.0, minor: 2.0)
        
        XCTAssertNotNil(region)
    }
    
    /**
     * Test creating a proximity region with invalid proximity IDs
     */
    func testSetInvalidProximityID() {
        var id = "".padding(toLength: 256, withPad: "PROXIMITY_ID", startingAt: 0)
        
        // test proximity ID greater than max
        var region = ProximityRegion(proximityID: id, major: 1.0, minor: 2.0)
        XCTAssertNil(region, "Proximity region should be nil if proximity ID fails to set.")

        // test proximity ID less than min
        id = ""
        region = ProximityRegion(proximityID: id, major: 1.0, minor: 2.0)
        XCTAssertNil(region, "Proximity region should be nil if proximity ID fails to set.")
    }
    
    /**
     * Test creating a proximity region with invalid major and minor
     */
    func testSetInvalidMajorMinor() {
        var major: Double = -1
        var minor: Double = -2
        
        // test major and minor less than min
        var region = ProximityRegion(proximityID: defaultRegionId, major: major, minor: minor)
        XCTAssertNil(region, "Proximity region should be nil if major or minor fails to set.")


        // test major and minor greater than max
        major = Double(UINT16_MAX + 1)
        minor = Double(UINT16_MAX + 1)
        region = ProximityRegion(proximityID: defaultRegionId, major: major, minor: minor)
        XCTAssertNil(region, "Proximity region should be nil if major or minor fails to set.")
    }
    
    /**
     * Test creating a proximity region with a valid RSSI
     */
    func testSetValidRSSI() {
        let region59dBm = ProximityRegion(proximityID: defaultRegionId, major: 1, minor: 2, rssi: -59)
        
        // test an RSSI of -59 dBm
        XCTAssertNotNil(region59dBm)
        
        let region0dBm = ProximityRegion(proximityID: defaultRegionId, major: 1, minor: 2, rssi: 0)
        
        // test RSSI of 0 dBm
        XCTAssertNotNil(region0dBm)
    }
    
    /**
     * Test creating a proximity region and setting a invalid RSSIs
     */
    func testSetInvalidRSSI() {
        var region = ProximityRegion(proximityID: defaultRegionId, major: 1, minor: 2, rssi: 101)
        XCTAssertNil(region, "RSSIs over 100 or under -100 dBm should be ignored.")
        
        region = ProximityRegion(proximityID: defaultRegionId, major: 1, minor: 2, rssi: -101)
        XCTAssertNil(region, "RSSIs over 100 or under -100 dBm should be ignored.")
    }
    
}
