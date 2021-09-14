/* Copyright Airship and Contributors */

/**
 * A proximity region defines an identifier, major and minor.
 */
@objc(UAProximityRegion)
public class ProximityRegion : NSObject {

    let latitude: Double?
    let longitude: Double?
    let rssi: Double?
    let proximityID: String
    let major: Double
    let minor: Double

    /**
     * Default constructor.
     *
     * - Parameter proximityID: The ID of the proximity region.
     * - Parameter major: The major.
     * - Parameter minor: The minor.
     * - Parameter rssi: The rssi.
     * - Parameter latitude: The latitude of the circular region's center point in degress.
     * - Parameter longitude: The longitude of the circular region's center point in degrees.
     *
     * - Returns: Proximity region object or `nil` if error occurs.
     */
    public init?(proximityID: String,
          major:Double,
          minor: Double,
          rssi: Double? = nil,
          latitude: Double? = nil,
          longitude: Double? = nil) {

        if ((latitude != nil || longitude != nil) && (latitude == nil || longitude == nil)) {
            AirshipLogger.error("Invalid proximity region. Both lat and long must both be defined if one is provied.")
            return nil
        }

        if let latitude = latitude {
            guard EventUtils.isValid(latitude: latitude) else {
                return nil
            }
        }

        if let longitude = longitude {
            guard EventUtils.isValid(longitude: longitude) else {
                return nil
            }
        }

        if let rssi = rssi {
            guard ProximityRegion.isValid(rssi: rssi) else {
                return nil
            }
        }

        guard ProximityRegion.isValid(proximityID: proximityID) else {
            return nil
        }


        guard ProximityRegion.isValid(major: major) else {
            return nil
        }

        guard ProximityRegion.isValid(minor: minor) else {
            return nil
        }

        self.proximityID = proximityID;
        self.major = major
        self.minor = minor
        self.rssi = rssi
        self.latitude = latitude
        self.longitude = longitude
    }

    /**
     * Factory method for creating a proximity region.
     *
     * - Parameter proximityID: The ID of the proximity region.
     * - Parameter major: The major.
     * - Parameter minor: The minor.
     *
     * - Returns: Proximity region object or `nil` if error occurs.
     */
    @objc(proximityRegionWithID:major:minor:)
    public class func proximityRegion(proximityID: String,
                                      major: Double,
                                      minor: Double) -> ProximityRegion?{
        return ProximityRegion(proximityID: proximityID, major: major, minor: minor)
    }

    /**
     * Factory method for creating a proximity region.
     *
     * - Parameter proximityID: The ID of the proximity region.
     * - Parameter major: The major.
     * - Parameter minor: The minor.
     * - Parameter rssi: The rssi.
     *
     * - Returns: Proximity region object or `nil` if error occurs.
     */
    @objc(proximityRegionWithID:major:minor:rssi:)
    public class func proximityRegion(proximityID: String,
                                      major: Double,
                                      minor: Double,
                                      rssi: Double) -> ProximityRegion? {
        return ProximityRegion(proximityID: proximityID, major: major, minor: minor, rssi: rssi)
    }


    /**
     * Factory method for creating a proximity region.
     *
     * - Parameter proximityID: The ID of the proximity region.
     * - Parameter major: The major.
     * - Parameter minor: The minor.
     * - Parameter latitude: The latitude of the circular region's center point in degress.
     * - Parameter longitude: The longitude of the circular region's center point in degrees.
     *
     * - Returns: Proximity region object or `nil` if error occurs.
     */
    @objc(proximityRegionWithID:major:minor:latitude:longitude:)
    public class func proximityRegion(proximityID: String,
                                      major: Double,
                                      minor: Double,
                                      latitude: Double,
                                      longitude: Double) -> ProximityRegion? {
        return ProximityRegion(proximityID: proximityID, major: major, minor: minor, latitude: latitude, longitude:longitude)
    }

    /**
     * Factory method for creating a proximity region.
     *
     * - Parameter proximityID: The ID of the proximity region.
     * - Parameter major: The major.
     * - Parameter minor: The minor.
     * - Parameter rssi: The rssi.
     * - Parameter latitude: The latitude of the circular region's center point in degress.
     * - Parameter longitude: The longitude of the circular region's center point in degrees.
     *
     * - Returns: Proximity region object or `nil` if error occurs.
     */
    @objc(proximityRegionWithID:major:minor:rssi:latitude:longitude:)
    public class func proximityRegion(proximityID: String,
                                      major: Double,
                                      minor: Double,
                                      rssi: Double,
                                      latitude: Double,
                                      longitude: Double) -> ProximityRegion? {
        return ProximityRegion(proximityID: proximityID, major: major, minor: minor, rssi: rssi, latitude: latitude, longitude:longitude)
    }

    private class func isValid(proximityID: String) -> Bool {
        guard proximityID.count > 0 && proximityID.count <= 255 else {
            AirshipLogger.error("Invalid proximityID \(proximityID). Must be between 1 and 255 characters")
            return false
        }
        return true
    }

    private class func isValid(rssi: Double) -> Bool {
        guard rssi >= -100 && rssi <= 100 else {
            AirshipLogger.error("Invalid RSSI \(rssi). Must be between -100 and 100")
            return false
        }
        return true
    }

    private class func isValid(major: Double) -> Bool {
        guard major >= 0 && major <= 65535 else {
            AirshipLogger.error("Invalid major \(major). Must be between 0 and 65535")
            return false
        }
        return true
    }

    private class func isValid(minor: Double) -> Bool {
        guard minor >= 0 && minor <= 65535 else {
            AirshipLogger.error("Invalid minor \(minor). Must be between 0 and 65535")
            return false
        }
        return true
    }
}
