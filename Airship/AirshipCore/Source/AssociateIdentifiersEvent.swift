/* Copyright Airship and Contributors */

/**
 * - Note: For Internal use only :nodoc:
 */
class AssociateIdentifiersEvent : NSObject, Event {

    @objc
    public var priority: EventPriority {
        get {
            return .normal
        }
    }

    @objc
    public var eventType : String {
        get {
            return "associate_identifiers"
        }
    }

    private let _data : [String : String]

    @objc
    public var data: [AnyHashable : Any] {
        get {
            return self._data
        }
    }

    @objc
    public init?(identifiers: AssociatedIdentifiers?) {
        self._data = identifiers?.allIDs ?? [:]

        guard self._data.count <= AssociatedIdentifiers.maxCount else {
            AirshipLogger.error("Associated identifiers count exceed \(AssociatedIdentifiers.maxCount)")
            return nil
        }

        let containsInvalid = self._data.contains {
            if ($0.key.count > AssociatedIdentifiers.maxCharacterCount) {
                AirshipLogger.error("Associated identifier \($0) key exceeds \(AssociatedIdentifiers.maxCharacterCount) characters")
                return true
            }

            if ($0.value.count > AssociatedIdentifiers.maxCharacterCount) {
                AirshipLogger.error("Associated identifier \($0) value exceeds \(AssociatedIdentifiers.maxCharacterCount) characters")
                return true
            }

            return false
        }

        guard !containsInvalid else {
            return nil
        }

        super.init()
    }
}
