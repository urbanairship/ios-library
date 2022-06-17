/* Copyright Airship and Contributors */

import Foundation

@available(iOS 13.0, *)
class Properties : ObservableObject {
    @Published var properties: [String: Any] = [:]
    
    func addProperty(key: String, value: Any) {
        properties[key] = value
    }
    
    func removeProperty(key: String) {
        properties.removeValue(forKey: key)
    }
    
    func getProperties() -> [String: Any] {
        return properties
    }
}
