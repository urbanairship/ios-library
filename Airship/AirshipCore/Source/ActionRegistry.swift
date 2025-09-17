/* Copyright Airship and Contributors */

/// This class is responsible for runtime-persisting actions and associating
/// them with names and predicates.
@MainActor
public class ActionRegistry {
    private var entries: [String: EntryHolder] = [:]


    public func registerEntry(
        names: [String],
        entry:  @escaping () -> ActionEntry
    ) {
        let entryHolder = EntryHolder(entryBlock: entry)
        names.forEach { name in
            entries[name] = entryHolder
        }
    }

    public func registerEntry(
        names: [String],
        entry:  ActionEntry
    ) {
        let entryHolder = EntryHolder(entryBlock: { entry })
        names.forEach { name in
            entries[name] = entryHolder
        }
    }

    @discardableResult
    public func removeEntry(name: String) -> Bool {
        guard let entryHolder = entries[name] else { return false }
        entries.compactMap { (key, value) in
            if (entryHolder === value) {
                return key
            }
            return nil
        }.forEach { name in
            entries[name] = nil
        }

        return true
    }

    @discardableResult
    public func updateEntry(name: String, action: any AirshipAction) -> Bool {
        guard let entryHolder = entries[name] else { return false }
        entryHolder.entry.action = action
        return true
    }

    @discardableResult
    public func updateEntry(name: String, predicate: (@Sendable (ActionArguments) async -> Bool)?) -> Bool {
        guard let entryHolder = entries[name] else { return false }
        entryHolder.entry.predicate = predicate
        return true
    }

    @discardableResult
    public func updateEntry(name: String, situation: ActionSituation, action: any AirshipAction) -> Bool {
        guard let entryHolder = entries[name] else { return false }
        entryHolder.entry.situationOverrides[situation] = action
        return true
    }

    public func entry(name: String) -> ActionEntry? {
        return self.entries[name]?.entry
    }

    public func registerActions(actionsManifests: [any ActionsManifest]) {
        actionsManifests.forEach { actionsManifest in
            actionsManifest.manifest.forEach { (names, entry) in
                registerEntry(names: names, entry: entry)
            }
        }
    }
}

/// Action registry entry
public struct ActionEntry: Sendable {
    var situationOverrides: [ActionSituation: any AirshipAction] = [:]
    var action: any AirshipAction
    var predicate: (@Sendable (ActionArguments) async -> Bool)?

    public init(
        action: any AirshipAction,
        situationOverrides: [ActionSituation: any AirshipAction] = [:],
        predicate: (@Sendable (ActionArguments) async -> Bool)? = nil
    ) {
        self.action = action
        self.predicate = predicate
    }

    func action(situation: ActionSituation) -> any AirshipAction {
        return situationOverrides[situation] ?? action
    }
}


fileprivate class EntryHolder {
    private var _entry: ActionEntry?
    var entry: ActionEntry {
        get {
            if let entry = _entry {
                return entry
            }
            let resolved = entryBlock()
            _entry = resolved
            return resolved
        }
        set {
            _entry = newValue
        }
    }

    private let entryBlock:  () -> ActionEntry
    init(entryBlock: @escaping () -> ActionEntry) {
        self.entryBlock = entryBlock
    }
    
}

/// Airship action manifest.
/// - Note: for internal use only.  :nodoc:
public protocol ActionsManifest {
    var manifest: [[String]: () -> ActionEntry]  { get }
}

struct DefaultActionsManifest: ActionsManifest {
    let manifest:  [[String]: () -> ActionEntry] = {
        var entries: [[String]: () -> ActionEntry] = [
            OpenExternalURLAction.defaultNames: {
                return ActionEntry(
                    action: OpenExternalURLAction(),
                    predicate: OpenExternalURLAction.defaultPredicate
                )
            },

            AddTagsAction.defaultNames: {
                return ActionEntry(
                    action: AddTagsAction(),
                    predicate: AddTagsAction.defaultPredicate
                )
            },

            RemoveTagsAction.defaultNames: {
                return ActionEntry(
                    action: RemoveTagsAction(),
                    predicate: RemoveTagsAction.defaultPredicate
                )
            },
            
            ModifyTagsAction.defaultNames: {
                return ActionEntry(
                    action: ModifyTagsAction(),
                    predicate: ModifyTagsAction.defaultPredicate
                )
            },

            DeepLinkAction.defaultNames: {
                return ActionEntry(
                    action: DeepLinkAction(),
                    predicate: DeepLinkAction.defaultPredicate
                )
            },

            AddCustomEventAction.defaultNames: {
                return ActionEntry(
                    action: AddCustomEventAction(),
                    predicate: AddCustomEventAction.defaultPredicate
                )
            },

            FetchDeviceInfoAction.defaultNames: {
                return ActionEntry(
                    action: FetchDeviceInfoAction(),
                    predicate: FetchDeviceInfoAction.defaultPredicate
                )
            },

            EnableFeatureAction.defaultNames: {
                return ActionEntry(
                    action: EnableFeatureAction(),
                    predicate: EnableFeatureAction.defaultPredicate
                )
            },

            ModifyAttributesAction.defaultNames: {
                return ActionEntry(
                    action: ModifyAttributesAction(),
                    predicate: ModifyAttributesAction.defaultPredicate
                )
            },

            SubscriptionListAction.defaultNames: {
                return ActionEntry(
                    action: SubscriptionListAction(),
                    predicate: SubscriptionListAction.defaultPredicate
                )
            },

            PromptPermissionAction.defaultNames: {
                return ActionEntry(
                    action: PromptPermissionAction(),
                    predicate: PromptPermissionAction.defaultPredicate
                )
            }
        ]

        #if os(iOS) || os(visionOS)
        entries[RateAppAction.defaultNames] = {
            return ActionEntry(
                action: RateAppAction(),
                predicate: RateAppAction.defaultPredicate
            )
        }

        entries[PasteboardAction.defaultNames] = {
            return ActionEntry(
                action: PasteboardAction()
            )
        }
        #endif


        #if os(iOS)
        entries[ShareAction.defaultNames] = {
            return ActionEntry(
                action: ShareAction(),
                predicate: ShareAction.defaultPredicate
            )
        }
        #endif

        return entries
    }()

}
