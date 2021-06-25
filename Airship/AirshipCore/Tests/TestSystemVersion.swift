import Foundation
import AirshipCore

@objc(UATestSystemVersion)
public class TestSystemVersion : UASystemVersion {

    @objc
    public var systemVersionOverride : String = "999.999.999"

    public override var currentSystemVersion : String {
        get {
            return systemVersionOverride
        }
    }

}
