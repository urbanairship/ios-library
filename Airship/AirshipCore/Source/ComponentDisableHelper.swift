/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
public final class ComponentDisableHelper: NSObject, @unchecked Sendable {
    public var onChange: (() -> Void)?
    private let dataStore: PreferenceDataStore
    private let key: String
    private let lock: AirshipLock = AirshipLock()

    public var enabled: Bool {
        get {
            self.dataStore.bool(forKey: self.key, defaultValue: true)
        }
        set {
            lock.sync {
                let oldValue = self.dataStore.bool(
                    forKey: self.key,
                    defaultValue: true
                )
                if oldValue != newValue {
                    self.dataStore.setBool(newValue, forKey: self.key)
                    self.onChange?()
                }
            }
        }
    }

    public init(dataStore: PreferenceDataStore, className: String) {
        self.dataStore = dataStore
        self.key = "UAComponent.\(className).enabled"
    }
}
