/* Copyright Airship and Contributors */

/**
 * @note For Interrnal use only :nodoc:
 */
@objc
public class UAAssociateIdentifiersEvent : NSObject, Event {

    @objc
    public var priority: UAEventPriority {
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
    public init?(identifiers: UAAssociatedIdentifiers?) {
        self._data = identifiers?.allIDs ?? [:]

        guard self._data.count <= UAAssociatedIdentifiers.maxCount else {
            AirshipLogger.error("Associated identifiers count exceed \(UAAssociatedIdentifiers.maxCount)")
            return nil
        }

        let containsInvalid = self._data.contains {
            if ($0.key.count > UAAssociatedIdentifiers.maxCharacterCount) {
                AirshipLogger.error("Associated identifier \($0) key exceeds \(UAAssociatedIdentifiers.maxCharacterCount) characters")
                return true
            }

            if ($0.value.count > UAAssociatedIdentifiers.maxCharacterCount) {
                AirshipLogger.error("Associated identifier \($0) value exceeds \(UAAssociatedIdentifiers.maxCharacterCount) characters")
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
