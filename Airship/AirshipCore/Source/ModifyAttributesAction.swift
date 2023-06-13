/* Copyright Airship and Contributors */

/// Modifies attributes.
///
/// An example JSON payload:
///
/// {
///     "channel": {
///         set: {"key": value, ... },
///         remove: ["attribute", ....]
///     },
///     "named_user": {
///         set: {"key": value, ... },
///         remove: ["attribute", ....]
///     }
/// }
///
///
/// Valid situations: `ActionSituation.foregroundPush`, `ActionSituation.launchedFromPush`
/// `ActionSituation.webViewInvocation`, `ActionSituation.foregroundInteractiveButton`,
/// `ActionSituation.backgroundInteractiveButton`, `ActionSituation.manualInvocation`, and
/// `ActionSituation.automation`
public final class ModifyAttributesAction: AirshipAction {

    /// Default names - "modify_attributes_action", "^a"
    public static let defaultNames = ["modify_attributes_action", "^a"]
    
    /// Default predicate - rejects foreground pushes with visible display options
    public static let defaultPredicate: @Sendable (ActionArguments) -> Bool = { args in
        return args.metadata[ActionArguments.isForegroundPresentationMetadataKey] as? Bool != true
    }
    

    private static let namedUserKey = "named_user"
    private static let channelsKey = "channel"
    private static let setActionKey = "set"
    private static let removeActionKey = "remove"


    private let channel: @Sendable () -> AirshipChannelProtocol
    private let contact: @Sendable () -> AirshipContactProtocol

    init(
        channel: @escaping @Sendable () -> AirshipChannelProtocol,
        contact: @escaping @Sendable () -> AirshipContactProtocol
    ) {
        self.channel = channel
        self.contact = contact
    }

    public convenience init() {
        self.init(
            channel: Airship.componentSupplier(),
            contact: Airship.componentSupplier()
        )
    }
   
    public func accepts(arguments: ActionArguments) async -> Bool {
        let unwrapped = arguments.value.unWrap()
        guard arguments.situation != .backgroundPush,
            let dict = unwrapped as? [String: [String: Any]]
        else {
            return false
        }

        let namedUserAttributes = dict[ModifyAttributesAction.namedUserKey]
        if namedUserAttributes != nil && !attributesValid(namedUserAttributes) {
            return false
        }

        let channelAttributes = dict[ModifyAttributesAction.channelsKey]
        if channelAttributes != nil && !attributesValid(channelAttributes) {
            return false
        }

        return namedUserAttributes != nil || channelAttributes != nil
    }

    public func perform(arguments: ActionArguments) async throws -> AirshipJSON? {
        let unwrapped = arguments.value.unWrap()
        let dict = unwrapped as? [String: [String: Any]]
        if let channelAttributes = dict?[ModifyAttributesAction.channelsKey] {
            applyEdits(channelAttributes, editor: channel().editAttributes())
        }

        if let namedUserAttributes = dict?[ModifyAttributesAction.namedUserKey]
        {
            applyEdits(namedUserAttributes, editor: contact().editAttributes())
        }

        return nil
    }

    func applyEdits(
        _ attributeMutations: [String: Any],
        editor: AttributesEditor?
    ) {
        if let sets = attributeMutations[ModifyAttributesAction.setActionKey]
            as? [String: Any]
        {
            sets.forEach { key, value in
                if let string = value as? String {
                    editor?.set(string: string, attribute: key)
                } else if let number = value as? NSNumber {
                    editor?.set(number: number, attribute: key)
                } else if let date = value as? Date {
                    editor?.set(date: date, attribute: key)
                } else {
                    AirshipLogger.error(
                        "Unable to process attribute \(key) value \(value)"
                    )
                }
            }
        }

        if let removes =
            attributeMutations[ModifyAttributesAction.removeActionKey]
            as? [String]
        {
            removes.forEach { editor?.remove($0) }
        }

        editor?.apply()
    }

    func attributesValid(_ attributeMutations: [String: Any]?) -> Bool {
        let sets = attributeMutations?[ModifyAttributesAction.setActionKey]
        if sets != nil {
            guard let sets = sets as? [String: Any] else {
                return false
            }
            if sets.count <= 0 {
                return false
            }
        }

        let removes = attributeMutations?[
            ModifyAttributesAction.removeActionKey
        ]
        if removes != nil {
            guard let removes = removes as? [String] else {
                return false
            }
            if removes.count <= 0 {
                return false
            }
        }

        return sets != nil || removes != nil
    }
}
