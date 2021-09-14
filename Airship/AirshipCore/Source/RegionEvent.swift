/* Copyright Airship and Contributors */

/**
 * Represents the boundary crossing event type.
 */
@objc
public enum UABoundaryEvent : Int {
    /**
     * Enter event
     */

    case enter = 1

    /**
     * Exit event
     */
    case exit = 2
}

/**
 * A region event captures information regarding a region event for analytics.
 */
@objc(UARegionEvent)
public class RegionEvent : NSObject, Event {

    @objc
    public static let regionIDKey = "region_id"
    static let sourceKey = "source"
    static let boundaryEventKey = "action"
    static let boundaryEventEnterValue = "enter"
    static let boundaryEventExitValue = "exit"
    static let latitudeKey = "latitude"
    static let longitudeKey = "longitude"
    static let proximityRegionKey = "proximity"
    static let proximityRegionIDKey = "proximity_id"
    static let proximityRegionMajorKey = "major"
    static let proximityRegionMinorKey = "minor"
    static let proximityRegionRSSIKey = "rssi"
    static let circularRegionKey = "circular_region"
    static let circularRegionRadiusKey = "radius"

    /**
     * The region's identifier.
     */
    @objc
    public let regionID: String

    /**
     * The source of the event.
     */
    @objc
    public let source: String

    /**
     * The type of boundary event.
     */
    @objc
    public let boundaryEvent: UABoundaryEvent

    /**
     * A circular region with a radius, and latitude/longitude from its center.
     */
    @objc
    public let circularRegion: CircularRegion?

    /**
     * A proximity region with an identifier, major and minor.
     */
    @objc
    public let proximityRegion: ProximityRegion?

    @objc
    public var eventType : String {
        get {
            return "region_event"
        }
    }

    @objc
    public var priority : EventPriority {
        get {
            return .high
        }
    }

    @objc
    public var data: [AnyHashable : Any] {
        get {
            return self.generatePayload(stringifyFields: true)
        }
    }

    /**
     * - Note: For internal use only. :nodoc:
     */
    @objc
    public var payload : [AnyHashable : Any] {
        get {
            return self.generatePayload(stringifyFields: false)
        }
    }

    /**
     * Default constructor.
     *
     * - Parameter regionID: The ID of the region.
     * - Parameter source: The source of the event.
     * - Parameter boundaryEvent: The type of boundary crossing event.
     * - Parameter circularRegion: The circular region info.
     * - Parameter proximityRegion: The proximiity region info.
     *
     * - Returns: Region event object or `nil` if error occurs.
     */
    public init?(regionID: String,
                 source: String,
                 boundaryEvent: UABoundaryEvent,
                 circularRegion: CircularRegion? = nil,
                 proximityRegion: ProximityRegion? = nil) {

        guard RegionEvent.isValid(regionID: regionID) else {
            return nil;
        }

        guard RegionEvent.isValid(source: source) else {
            return nil;
        }

        self.regionID = regionID
        self.source = source
        self.boundaryEvent = boundaryEvent
        self.circularRegion = circularRegion
        self.proximityRegion = proximityRegion
        super.init()
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
    public class func regionEvent(regionID: String, source: String, boundaryEvent: UABoundaryEvent) -> RegionEvent? {
        return RegionEvent(regionID: regionID, source: source, boundaryEvent: boundaryEvent)
    }

    /**
     * Factory method for creating a region event.
     *
     * - Parameter regionID: The ID of the region.
     * - Parameter source: The source of the event.
     * - Parameter boundaryEvent: The type of boundary crossing event.
     * - Parameter circularRegion: The circular region info.
     * - Parameter proximityRegion: The proximiity region info.
     *
     * - Returns: Region event object or `nil` if error occurs.
     */
    @objc(regionEventWithRegionID:source:boundaryEvent:circularRegion:proximityRegion:)
    public class func regionEvent(regionID: String, source: String, boundaryEvent: UABoundaryEvent, circularRegion: CircularRegion?, proximityRegion: ProximityRegion?) -> RegionEvent? {
        return RegionEvent(regionID: regionID, source: source, boundaryEvent: boundaryEvent, circularRegion: circularRegion, proximityRegion: proximityRegion)
    }

    private class func isValid(regionID: String) -> Bool {
        guard regionID.count >= 1 && regionID.count <= 255 else {
            AirshipLogger.error("Invalid region ID \(regionID). Must be between 1 and 255 characters")
            return false
        }
        return true
    }

    private class func isValid(source: String) -> Bool {
        guard source.count >= 1 && source.count <= 255 else {
            AirshipLogger.error("Invalid source ID \(source). Must be between 1 and 255 characters")
            return false
        }
        return true
    }

    private func generatePayload(stringifyFields: Bool) -> [String: Any] {
        var dictionary: [String : Any] = [:]
        dictionary[RegionEvent.sourceKey] = self.source
        dictionary[RegionEvent.regionIDKey] = self.regionID

        switch(self.boundaryEvent) {
        case .enter:
            dictionary[RegionEvent.boundaryEventKey] = RegionEvent.boundaryEventEnterValue
        case .exit:
            dictionary[RegionEvent.boundaryEventKey] = RegionEvent.boundaryEventExitValue
        }

        if let proximityRegion = self.proximityRegion {
            var proximityData : [String : Any] = [:]
            proximityData[RegionEvent.proximityRegionIDKey] = proximityRegion.proximityID
            proximityData[RegionEvent.proximityRegionMajorKey] = proximityRegion.major
            proximityData[RegionEvent.proximityRegionMinorKey] = proximityRegion.minor
            proximityData[RegionEvent.proximityRegionRSSIKey] = proximityRegion.rssi

            if (proximityRegion.latitude != nil && proximityRegion.longitude != nil) {
                if (stringifyFields) {
                    proximityData[RegionEvent.latitudeKey] = String(format: "%.7f", proximityRegion.latitude!)
                    proximityData[RegionEvent.longitudeKey] = String(format: "%.7f", proximityRegion.longitude!)
                } else {
                    proximityData[RegionEvent.latitudeKey] = proximityRegion.latitude
                    proximityData[RegionEvent.longitudeKey] = proximityRegion.longitude
                }
            }

            dictionary[RegionEvent.proximityRegionKey] = proximityData
        }

        if let circularRegion = self.circularRegion {
            var circularData : [String : Any] = [:]
            if (stringifyFields) {
                circularData[RegionEvent.circularRegionRadiusKey] = String(format: "%.1f", circularRegion.radius)
                circularData[RegionEvent.latitudeKey] = String(format: "%.7f", circularRegion.latitude)
                circularData[RegionEvent.longitudeKey] = String(format: "%.7f", circularRegion.longitude)
            } else {
                circularData[RegionEvent.circularRegionRadiusKey] = circularRegion.radius
                circularData[RegionEvent.latitudeKey] = circularRegion.latitude
                circularData[RegionEvent.longitudeKey] = circularRegion.longitude
            }
            dictionary[RegionEvent.circularRegionKey] = circularData
        }

        return dictionary
    }
}
