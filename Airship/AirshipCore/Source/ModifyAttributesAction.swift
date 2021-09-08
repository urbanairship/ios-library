/* Copyright Airship and Contributors */


/**
 * Modifies attributes This Action is registered under the
 * names ^a and "modify_attributes_action".
 *
 * An example JSON payload:
 *
 * {
 *     "channel": {
 *         set: {"key": value, ... },
 *         remove: ["attribute", ....]
 *     },
 *     "named_user": {
 *         set: {"key": value, ... },
 *         remove: ["attribute", ....]
 *     }
 * }
 *
 *
 * Valid situations: UASituationForegroundPush, UASituationLaunchedFromPush
 * UASituationWebViewInvocation, UASituationForegroundInteractiveButton,
 * UASituationBackgroundInteractiveButton, UASituationManualInvocation, and
 * UASituationAutomation
 *
 * Default predicate: Rejects foreground pushes with visible display options
 *
 * Result value: nil
 *
 * Error: nil
 *
 * Fetch result: UAActionFetchResultNoData
 */
@objc(UAModifyAttributesAction)
public class ModifyAttributesAction : NSObject, Action {
    
    private static let namedUserKey = "named_user"
    private static let channelsKey = "channel"
    private static let setActionKey = "set"
    private static let removeActionKey = "remove"

    @objc
    public static let name = "modify_attributes_action"
    
    @objc
    public static let shortName = "^a"

    private let channel: () -> ChannelProtocol
    private let contact: () -> ContactProtocol
    
    @objc
    public override convenience init() {
        self.init(channel: Channel.supplier,
                  contact: Contact.supplier)
    }
    
    @objc
    public init(channel: @escaping () -> ChannelProtocol,
                contact: @escaping () -> ContactProtocol) {
        self.channel = channel
        self.contact = contact
    }
    
    public func acceptsArguments(_ arguments: ActionArguments) -> Bool {
        guard arguments.situation != .backgroundPush,
              let dict = arguments.value as? [String : [String : Any]] else {
            return false
        }
        
        let namedUserAttributes = dict[ModifyAttributesAction.namedUserKey]
        if (namedUserAttributes != nil && !attributesValid(namedUserAttributes)) {
            return false
        }
        
        let channelAttributes = dict[ModifyAttributesAction.channelsKey]
        if (channelAttributes != nil && !attributesValid(channelAttributes)) {
            return false
        }
        
        return namedUserAttributes != nil || channelAttributes != nil
    }

    public func perform(with arguments: ActionArguments, completionHandler: UAActionCompletionHandler) {
        let dict = arguments.value as? [String : [String : Any]]
        if let channelAttributes = dict?[ModifyAttributesAction.channelsKey] {
            applyEdits(channelAttributes, editor: channel().editAttributes())
        }
        
        if let namedUserAttributes = dict?[ModifyAttributesAction.namedUserKey] {
            applyEdits(namedUserAttributes, editor: contact().editAttributes())
        }
    }
    
    func applyEdits(_ attributeMutations : [String : Any], editor: AttributesEditor?) {
        if let sets = attributeMutations[ModifyAttributesAction.setActionKey] as? [String : Any] {
            sets.forEach { key, value in
                if let string = value as? String {
                    editor?.set(string: string, attribute: key)
                } else if let number = value as? NSNumber {
                    editor?.set(number: number, attribute: key)
                } else if let date = value as? Date {
                    editor?.set(date: date, attribute: key)
                } else {
                    AirshipLogger.error("Unable to process attribute \(key) value \(value)")
                }
            }
        }
        
        if let removes = attributeMutations[ModifyAttributesAction.removeActionKey] as? [String] {
            removes.forEach { editor?.remove($0) }
        }
        
        editor?.apply()
    }

    func attributesValid(_ attributeMutations: [String : Any]?) -> Bool {
        let sets = attributeMutations?[ModifyAttributesAction.setActionKey]
        if sets != nil {
            if let sets = sets as? [String : Any] {
                if (sets.count <= 0) {
                    return false
                }
            } else {
                return false
            }
        }

        let removes = attributeMutations?[ModifyAttributesAction.removeActionKey]
        if removes != nil {
            if let removes = removes as? [String] {
                if (removes.count <= 0) {
                    return false
                }
            } else {
                return false
            }
        }
        
        return sets != nil || removes != nil
    }
}
