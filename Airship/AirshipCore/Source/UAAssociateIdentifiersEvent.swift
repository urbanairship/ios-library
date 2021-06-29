/* Copyright Airship and Contributors */

/**
 * @note For Interrnal use only :nodoc:
 */
@objc
public class UAAssociateIdentifiersEvent : UAEvent {
    @objc
    public override var eventType : String {
        get {
            return "associate_identifiers"
        }
    }

    private let _data : [String : String]

    @objc
    public override var data: [AnyHashable : Any] {
        get {
            return self._data
        }
    }

    @objc
    public init?(identifiers: UAAssociatedIdentifiers?) {
        self._data = identifiers?.allIDs ?? [:]

        guard self._data.count <= UAAssociatedIdentifiersMaxCount else {
            AirshipLogger.error("Associated identifiers count exceed \(UAAssociatedIdentifiersMaxCount)")
            return nil
        }

        let containsInvalid = self._data.contains {
            if ($0.key.count > UAAssociatedIdentifiersMaxCount) {
                AirshipLogger.error("Associated identifier \($0) key exceeds \(UAAssociatedIdentifiersMaxCharacterCount) characters")
                return true
            }

            if ($0.value.count > UAAssociatedIdentifiersMaxCount) {
                AirshipLogger.error("Associated identifier \($0) value exceeds \(UAAssociatedIdentifiersMaxCharacterCount) characters")
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
