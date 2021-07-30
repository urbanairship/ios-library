import AirshipPreferenceCenter

class MockPreferenceCenterOpenDelegate : PreferenceCenterOpenDelegate {
    var lastOpenId: String?
    var result : Bool = false
    
    func openPreferenceCenter(_ identifier: String) -> Bool {
        self.lastOpenId = identifier
        return false
    }
}
