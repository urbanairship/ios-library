/* Copyright Airship and Contributors */

import Foundation

@available(iOS 13.0, *)
class Identifiers: ObservableObject {
    @Published var identifiers: [String: String] = [:]
    
    func addIdentifier(key: String, value: String) {
        identifiers[key] = value
    }
    
    func removeIdentifier(key: String, value: String) {
        identifiers.removeValue(forKey: key)
    }
    
    func getIdentifiers() -> [String: String] {
        return identifiers
    }
}
