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
@objc
public class UARegionEvent : NSObject, UAEvent {

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
    public let circularRegion: UACircularRegion?

    /**
     * A proximity region with an identifier, major and minor.
     */
    @objc
    public let proximityRegion: UAProximityRegion?

    @objc
    public var eventType : String {
        get {
            return "region_event"
        }
    }

    @objc
    public var priority : UAEventPriority {
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
     * @note For internal use only. :nodoc:
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
     * @param regionID The ID of the region.
     * @param source The source of the event.
     * @param boundaryEvent The type of boundary crossing event.
     * @param circularRegion The circular region info.
     * @param proximityRegion The proximiity region info.
     *
     * @return Region event object or `nil` if error occurs.
     */
    public init?(regionID: String,
                 source: String,
                 boundaryEvent: UABoundaryEvent,
                 circularRegion: UACircularRegion? = nil,
                 proximityRegion: UAProximityRegion? = nil) {

        guard UARegionEvent.isValid(regionID: regionID) else {
            return nil;
        }

        guard UARegionEvent.isValid(source: source) else {
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
     * @param regionID The ID of the region.
     * @param source The source of the event.
     * @param boundaryEvent The type of boundary crossing event.
     *
     * @return Region event object or `nil` if error occurs.
     */
    @objc(regionEventWithRegionID:source:boundaryEvent:)
    public class func regionEvent(regionID: String, source: String, boundaryEvent: UABoundaryEvent) -> UARegionEvent? {
        return UARegionEvent(regionID: regionID, source: source, boundaryEvent: boundaryEvent)
    }

    /**
     * Factory method for creating a region event.
     *
     * @param regionID The ID of the region.
     * @param source The source of the event.
     * @param boundaryEvent The type of boundary crossing event.
     * @param circularRegion The circular region info.
     * @param proximityRegion The proximiity region info.
     *
     * @return Region event object or `nil` if error occurs.
     */
    @objc(regionEventWithRegionID:source:boundaryEvent:circularRegion:proximityRegion:)
    public class func regionEvent(regionID: String, source: String, boundaryEvent: UABoundaryEvent, circularRegion: UACircularRegion?, proximityRegion: UAProximityRegion?) -> UARegionEvent? {
        return UARegionEvent(regionID: regionID, source: source, boundaryEvent: boundaryEvent, circularRegion: circularRegion, proximityRegion: proximityRegion)
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
        dictionary[UARegionEvent.sourceKey] = self.source
        dictionary[UARegionEvent.regionIDKey] = self.regionID

        switch(self.boundaryEvent) {
        case .enter:
            dictionary[UARegionEvent.boundaryEventKey] = UARegionEvent.boundaryEventEnterValue
        case .exit:
            dictionary[UARegionEvent.boundaryEventKey] = UARegionEvent.boundaryEventExitValue
        }

        if let proximityRegion = self.proximityRegion {
            var proximityData : [String : Any] = [:]
            proximityData[UARegionEvent.proximityRegionIDKey] = proximityRegion.proximityID
            proximityData[UARegionEvent.proximityRegionMajorKey] = proximityRegion.major
            proximityData[UARegionEvent.proximityRegionMinorKey] = proximityRegion.minor
            proximityData[UARegionEvent.proximityRegionRSSIKey] = proximityRegion.rssi

            if (proximityRegion.latitude != nil && proximityRegion.longitude != nil) {
                if (stringifyFields) {
                    proximityData[UARegionEvent.latitudeKey] = String(format: "%.7f", proximityRegion.latitude!)
                    proximityData[UARegionEvent.longitudeKey] = String(format: "%.7f", proximityRegion.longitude!)
                } else {
                    proximityData[UARegionEvent.latitudeKey] = proximityRegion.latitude
                    proximityData[UARegionEvent.longitudeKey] = proximityRegion.longitude
                }
            }

            dictionary[UARegionEvent.proximityRegionKey] = proximityData
        }

        if let circularRegion = self.circularRegion {
            var circularData : [String : Any] = [:]
            if (stringifyFields) {
                circularData[UARegionEvent.circularRegionRadiusKey] = String(format: "%.1f", circularRegion.radius)
                circularData[UARegionEvent.latitudeKey] = String(format: "%.7f", circularRegion.latitude)
                circularData[UARegionEvent.longitudeKey] = String(format: "%.7f", circularRegion.longitude)
            } else {
                circularData[UARegionEvent.circularRegionRadiusKey] = circularRegion.radius
                circularData[UARegionEvent.latitudeKey] = circularRegion.latitude
                circularData[UARegionEvent.longitudeKey] = circularRegion.longitude
            }
            dictionary[UARegionEvent.circularRegionKey] = circularData
        }

        return dictionary
    }
}
