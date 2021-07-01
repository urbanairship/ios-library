import AirshipPreferenceCenter

class MockPreferenceCenterOpenDelegate : PreferenceCenterOpenDelegate {
    var lastOpenId: String?
    
    func open(id: String) {
        self.lastOpenId = id
    }
}
