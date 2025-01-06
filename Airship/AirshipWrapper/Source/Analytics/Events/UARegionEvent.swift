/* Copyright Airship and Contributors */

import Foundation
public import AirshipCore

/// This singleton provides an interface to the functionality provided by the Airship iOS Push API.
@objc
public class UARegionEvent: NSObject {
    
    var regionEvent: RegionEvent?
    
    @objc
    public static let eventType: String = "region_event"
    
    @objc
    public static let regionIDKey = "region_id"
    
    /**
     * Default constructor.
     *
     * - Parameter regionID: The ID of the region.
     * - Parameter source: The source of the event.
     * - Parameter boundaryEvent: The type of boundary crossing event.
     * - Parameter circularRegion: The circular region info.
     * - Parameter proximityRegion: The proximity region info.
     *
     * - Returns: Region event object or `nil` if error occurs.
     */
    public convenience init?(
        regionID: String,
        source: String,
        boundaryEvent: AirshipBoundaryEvent,
        circularRegion: CircularRegion? = nil,
        proximityRegion: ProximityRegion? = nil
    ) {
        let regionEvent = RegionEvent(regionID: regionID, source: source, boundaryEvent: boundaryEvent)
        self.init(event: regionEvent)
    }
    
    public init(event: RegionEvent?) {
        self.regionEvent = event
    }
    
    /**
     * Factory method for creating a region event.
     *
     * - Parameter regionID: The ID of the region.
     * - Parameter source: The source of the event.
     * - Parameter boundaryEvent: The type of boundary crossing event.
     *
     * - Returns: Region event object or `nil` if error occurs.
     */
    @objc(regionEventWithRegionID:source:boundaryEvent:)
    public class func regionEvent(
        regionID: String,
        source: String,
        boundaryEvent: UABoundaryEvent
    ) -> UARegionEvent {
        let regionEvent = RegionEvent(regionID: regionID, source: source, boundaryEvent: boundaryEvent.event)
        return UARegionEvent(event: regionEvent)
    }
    
    /**
     * Factory method for creating a region event.
     *
     * - Parameter regionID: The ID of the region.
     * - Parameter source: The source of the event.
     * - Parameter boundaryEvent: The type of boundary crossing event.
     * - Parameter circularRegion: The circular region info.
     * - Parameter proximityRegion: The proximity region info.
     *
     * - Returns: Region event object or `nil` if error occurs.
     */
    
    @objc(
        regionEventWithRegionID:
            source:
            boundaryEvent:
            circularRegion:
            proximityRegion:
    )
    public class func regionEvent(
        regionID: String,
        source: String,
        boundaryEvent: UABoundaryEvent,
        circularRegion: UACircularRegion?,
        proximityRegion: UAProximityRegion?
    ) -> UARegionEvent {
        let regionEvent = RegionEvent(regionID: regionID, source: source, boundaryEvent: boundaryEvent.event, circularRegion: circularRegion?.region, proximityRegion: proximityRegion?.region)
        return UARegionEvent(event: regionEvent)
    }
}

@objc
public class UABoundaryEvent: NSObject {
    var event: AirshipBoundaryEvent
    
    public init(boundaryEvent: AirshipBoundaryEvent) {
        event = boundaryEvent
    }
}

@objc
public class UACircularRegion: NSObject {
    var region: CircularRegion
    
    public init(circularRegion: CircularRegion) {
        region = circularRegion
    }
}

@objc
public class UAProximityRegion: NSObject {
    var region: ProximityRegion
    
    public init(proximityRegion: ProximityRegion) {
        region = proximityRegion
    }
}
