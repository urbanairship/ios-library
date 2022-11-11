import AirshipCore
import Foundation

@objc(UATestSystemVersion)
public class TestSystemVersion: SystemVersion {

    @objc
    public var systemVersionOverride: String = "999.999.999"

    public override var currentSystemVersion: String {
        return systemVersionOverride
    }

}
