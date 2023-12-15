/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class CircularRegionTest: XCTestCase {
    private var coordinates: (latitude: Double, longitude: Double) = (45.5200, 122.6819)
    
    /**
     * Test creating a circular region with a valid radius
     */
    func testSetValidRadius() {
        let region = CircularRegion(radius: 10, latitude: coordinates.latitude, longitude: coordinates.longitude)
        XCTAssertNotNil(region)
    }
    
    /**
     * Test creating a circular region and adding an invalid radius
     */
    func testSetInvalidRadius() {
        // test radius greater than max
        var region = CircularRegion(radius: 100001, latitude: coordinates.latitude, longitude: coordinates.longitude)
        XCTAssertNil(region, "Circular region should be nil if radius fails to set.")
        
        // test radius less than min
        region = CircularRegion(radius: 0, latitude: coordinates.latitude, longitude: coordinates.longitude)
        XCTAssertNil(region, "Circular region should be nil if radius fails to set.")
    }
    
    /**
     * Test creating a circular region and adding a valid latitude
     */
    func testSetValidLatitude() {
        // test Portland's latitude
        var circularRegion = CircularRegion(radius: 10, latitude: coordinates.latitude, longitude: coordinates.longitude)
        XCTAssertNotNil(circularRegion)

        // test latitude of 0 degrees
        circularRegion = CircularRegion(radius: 10, latitude: 0, longitude: coordinates.longitude)
        XCTAssertNotNil(circularRegion)
    }
    
    /**
     * Test creating a circular region and adding invalid latitudes
     */
    func testSetInvalidLatitude() {
        // test latitude greater than max
        var circularRegion = CircularRegion(radius: 10, latitude: 91, longitude: coordinates.longitude)
        XCTAssertNil(circularRegion, "Circular region should be nil if latitude fails to set.")

        // test latitude less than min
        circularRegion = CircularRegion(radius: 10, latitude: -91, longitude: coordinates.longitude)
        XCTAssertNil(circularRegion, "Circular region should be nil if latitude fails to set.")
    }
    
    /**
     * Test creating a circular region and adding a valid longitude
     */
    func testSetValidLongitude() {
        // test Portland's longitude
        var circularRegion = CircularRegion(radius: 10, latitude: coordinates.latitude, longitude: coordinates.longitude)
        XCTAssertNotNil(circularRegion)

        // test longitude of 0 degrees
        circularRegion = CircularRegion(radius: 10, latitude: coordinates.latitude, longitude: 0)
        XCTAssertNotNil(circularRegion)
    }
    
    /**
     * Test creating a circular region and adding invalid longitudes
     */
    func testSetInvalidLongitude() {
        // test longitude greater than max
        var circularRegion = CircularRegion(radius: 10, latitude: coordinates.latitude, longitude: 181)
        XCTAssertNil(circularRegion)

        // test longitude less than min
        circularRegion = CircularRegion(radius: 10, latitude: coordinates.latitude, longitude: -181)
        XCTAssertNil(circularRegion)
    }
}
