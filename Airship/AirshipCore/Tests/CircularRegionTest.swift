/* Copyright Airship and Contributors */

import Testing
@testable import AirshipCore

@Suite
struct CircularRegionTest {
    private let coordinates: (latitude: Double, longitude: Double) = (45.5200, 122.6819)

    /**
     * Test creating a circular region with a valid radius
     */
    @Test
    func testSetValidRadius() {
        let region = CircularRegion(radius: 10, latitude: coordinates.latitude, longitude: coordinates.longitude)
        #expect(region != nil)
    }

    /**
     * Test creating a circular region and adding an invalid radius
     */
    @Test
    func testSetInvalidRadius() {
        // test radius greater than max
        var region = CircularRegion(radius: 100001, latitude: coordinates.latitude, longitude: coordinates.longitude)
        #expect(region == nil, "Circular region should be nil if radius fails to set.")

        // test radius less than min
        region = CircularRegion(radius: 0, latitude: coordinates.latitude, longitude: coordinates.longitude)
        #expect(region == nil, "Circular region should be nil if radius fails to set.")
    }

    /**
     * Test creating a circular region and adding a valid latitude
     */
    @Test
    func testSetValidLatitude() {
        // test Portland's latitude
        var circularRegion = CircularRegion(radius: 10, latitude: coordinates.latitude, longitude: coordinates.longitude)
        #expect(circularRegion != nil)

        // test latitude of 0 degrees
        circularRegion = CircularRegion(radius: 10, latitude: 0, longitude: coordinates.longitude)
        #expect(circularRegion != nil)
    }

    /**
     * Test creating a circular region and adding invalid latitudes
     */
    @Test
    func testSetInvalidLatitude() {
        // test latitude greater than max
        var circularRegion = CircularRegion(radius: 10, latitude: 91, longitude: coordinates.longitude)
        #expect(circularRegion == nil, "Circular region should be nil if latitude fails to set.")

        // test latitude less than min
        circularRegion = CircularRegion(radius: 10, latitude: -91, longitude: coordinates.longitude)
        #expect(circularRegion == nil, "Circular region should be nil if latitude fails to set.")
    }

    /**
     * Test creating a circular region and adding a valid longitude
     */
    @Test
    func testSetValidLongitude() {
        // test Portland's longitude
        var circularRegion = CircularRegion(radius: 10, latitude: coordinates.latitude, longitude: coordinates.longitude)
        #expect(circularRegion != nil)

        // test longitude of 0 degrees
        circularRegion = CircularRegion(radius: 10, latitude: coordinates.latitude, longitude: 0)
        #expect(circularRegion != nil)
    }

    /**
     * Test creating a circular region and adding invalid longitudes
     */
    @Test
    func testSetInvalidLongitude() {
        // test longitude greater than max
        var circularRegion = CircularRegion(radius: 10, latitude: coordinates.latitude, longitude: 181)
        #expect(circularRegion == nil)

        // test longitude less than min
        circularRegion = CircularRegion(radius: 10, latitude: coordinates.latitude, longitude: -181)
        #expect(circularRegion == nil)
    }
}
