/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
@objc(UAComponentDisableHelper)
public class ComponentDisableHelper : NSObject {
    @objc
    public var onChange: (() -> Void)?
    private let dataStore: PreferenceDataStore
    private let key: String
    
    @objc
    public var enabled: Bool {
        get {
            self.dataStore.bool(forKey: self.key, defaultValue: true)
        }
        set {
            let oldValue = self.dataStore.bool(forKey: self.key, defaultValue: true)
            if (oldValue != newValue) {
                self.dataStore.setBool(newValue, forKey: self.key)
                self.onChange?()
            }
        }
    }
    
    @objc
    public init(dataStore: PreferenceDataStore, className: String) {
        self.dataStore = dataStore
        self.key = "UAComponent.\(className).enabled"
    }
}
