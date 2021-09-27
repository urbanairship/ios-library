/* Copyright Airship and Contributors */

/**
 * This class is responsible for runtime-persisting actions and associating
 * them with names and predicates.
 */
@objc(UAActionRegistry)
public class ActionRegistry : NSObject {
    
    private static let actionKey = "action"
    private static let namesKey = "names"
    private static let predicateKey = "predicate"

    private var _entries: [ActionRegistryEntry] = []
    private var lock = Lock()
    
    /**
     * A set of the current registered entries
     */
    @objc
    public var registeredEntries: Set<ActionRegistryEntry> {
        get {
            return Set(self._entries)
        }
    }
    
    /**
     * Factory method to create an action registry with the default action entries.
     * - Returns: An action registry with the default action entries.
     */
    @objc
    public class func defaultRegistry() -> ActionRegistry {
        let registry = ActionRegistry()
        registry.registerDefaultActions()
        return registry
    }

    /**
     * Registers an action.
     *
     * If another entry is registered under specified name, it will be removed from that
     * entry and used for the new action.
     *
     * - Parameters:
     *   - action: The action.
     *   - names: The action's names.
     * - Returns: true if the action was able to be registered, otherwise false.
     */
    @objc(registerAction:names:)
    @discardableResult
    public func register(_ action: Action, names: [String]) -> Bool {
        return register(action, names: names, predicate: nil)
    }

    /**
     * Registers an action.
     *
     * If another entry is registered under specified name, it will be removed from that
     * entry and used for the new action.
     *
     * - Parameters:
     *   - action: The action.
     *   - name: The action's name.
     * - Returns: true if the action was able to be registered, otherwise false.
     */
    @objc(registerAction:name:)
    @discardableResult
    public func register(_ action: Action, name: String) -> Bool {
        return register(action, name: name, predicate: nil)
    }

    /**
     * Registers an action.
     *
     * If another entry is registered under specified name, it will be removed from that
     * entry and used for the new action.
     *
     * - Parameters:
     *   - action: The action.
     *   - name: The action's name.
     *   - predicate: The action's predicate.
     * - Returns: true if the action was able to be registered, otherwise false.
     */
    @objc(registerAction:name:predicate:)
    @discardableResult
    public func register(_ action: Action, name: String, predicate: UAActionPredicate?) -> Bool {
        return register(action, names: [name], predicate: predicate)
    }
    
    /**
     * Registers an action.
     *
     * If another entry is registered under specified name, it will be removed from that
     * entry and used for the new action.
     *
     * - Parameters:
     *   - action: The action.
     *   - names: The action's names.
     *   - predicate: The action's predicate.
     * - Returns: true if the action was able to be registered, otherwise false.
     */
    @objc(registerAction:names:predicate:)
    @discardableResult
    public func register(_ action: Action, names: [String], predicate: UAActionPredicate?) -> Bool {
        let entry = ActionRegistryEntry(action: action)
        return register(entry, names: names, predicate: predicate)
    }
    
    /**
     * Registers an action by class name..
     *
     * If another entry is registered under specified name, it will be removed from that
     * entry and used for the new action.
     *
     * - Parameters:
     *   - actionClass: The action's class.
     *   - names: The action's names.
     * - Returns: true if the action was able to be registered, otherwise false.
     */
    @objc(registerActionClass:names:)
    @discardableResult
    public func register(_ actionClass: AnyClass, names: [String]) -> Bool {
        return register(actionClass, names: names, predicate: nil)
    }

    /**
     * Registers an action by class name..
     *
     * If another entry is registered under specified name, it will be removed from that
     * entry and used for the new action.
     *
     * - Parameters:
     *   - actionClass: The action's class.
     *   - name: The action's name.
     * - Returns: true if the action was able to be registered, otherwise false.
     */
    @objc(registerActionClass:name:)
    @discardableResult
    public func register(_ actionClass: AnyClass, name: String) -> Bool {
        return register(actionClass, name: name, predicate: nil)
    }
  
    /**
     * Registers an action by class name..
     *
     * If another entry is registered under specified name, it will be removed from that
     * entry and used for the new action.
     *
     * - Parameters:
     *   - actionClass: The action's class.
     *   - name: The action's name.
     *   - predicate: The action's predicate.
     * - Returns: true if the action was able to be registered, otherwise false.
     */
    @objc(registerActionClass:name:predicate:)
    @discardableResult
    public func register(_ actionClass: AnyClass, name: String, predicate: UAActionPredicate?) -> Bool {
        return register(actionClass, names: [name], predicate: predicate)
    }
    
    /**
     * Registers an action by class name..
     *
     * If another entry is registered under specified name, it will be removed from that
     * entry and used for the new action.
     *
     * - Parameters:
     *   - actionClass: The action's class.
     *   - names: The action's names.
     *   - predicate:The action's predicate.
     * - Returns: true if the action was able to be registered, otherwise false.
     */
    @objc(registerActionClass:names:predicate:)
    @discardableResult
    public func register(_ actionClass: AnyClass, names: [String], predicate: UAActionPredicate?) -> Bool {
        guard actionClass is Action.Type else {
            AirshipLogger.error("Unable to register an action class that isn't a subclass of UAAction.")
            return false
        }

        guard let actionClass = actionClass as? NSObject.Type else {
            AirshipLogger.error("Unable to register an action class that isn't a subclass of NSObject.")
            return false
        }
        
        let entry = ActionRegistryEntry(actionClass: actionClass)
        return register(entry, names: names, predicate: predicate)
    }
    
    /**
     * Removes an entry by name.
     * - Parameters:
     *   - name: The name of the entry to remove.
     */
    @objc(removeEntryWithName:)
    public func removeEntry(_ name: String)  {
        lock.sync {
            self._entries.removeAll(where: { $0.names.contains(name) })
        }
    }
    
    /**
     * Removes a name for a registered entry.
     * - Parameters:
     *   - name: The name to remove.
     */
    @objc(removeName:)
    public func removeName(_ name: String) {
        self.removeNames([name])
    }
    
    func removeNames(_ names: [String]) {
        lock.sync {
            names.forEach { name in
                if let entry = registryEntry(name) {
                    entry._names.removeAll(where: { $0 == name })
                }
            }
            
            self._entries.removeAll(where: { $0.names.isEmpty })
        }
    }

    /**
     * Adds a name to a registered entry.
     * - Parameters:
     *   - name: The name to add
     *   - entryName:The name of the entry.
     * - Returns: true if the entry was found, othewrise false..
     */
    @objc
    @discardableResult
    public func addName(_ name: String, forEntryWithName entryName: String) -> Bool {
        var result = false
        lock.sync {
            if let entry = registryEntry(entryName) {
                removeNames([name])
                entry._names.append(name)
                result = true
            }
        }
        return result
    }

    /**
     * Adds a situation override for the entry.
     * - Parameters:
     *   - situation: The situation to override.
     *   - name: The name of the entry.
     *   - action: The action.
     */
    @objc
    @discardableResult
    public func addSituationOverride(_ situation: Situation,
                              forEntryWithName name: String,
                              action: Action?) -> Bool {
        var result = false
        lock.sync {
            if let entry = registryEntry(name) {
                entry._situationOverrides[situation] = action
                result = true
            }
        }
        return result
    }
    
    /**
     * Gets an entry by name.
     * - Parameters:
     *   - name: The name of the entry.
     * - Returns: The entry if found, otherwise null.
     */
    @objc(registryEntryWithName:)
    public func registryEntry(_ name: String) -> ActionRegistryEntry? {
        var result: ActionRegistryEntry? = nil
        lock.sync {
            result = self._entries.first(where: {$0.names.contains(name) })
        }
        return result
    }

    /**
     * Updates an entry's predicate.
     * - Parameters:
     *   - predicate: The predicate.
     *   - name: The name of the entry.
     * - Returns: The entry if found, otherwise null.
     */
    @objc(updatePredicate:forEntryWithName:)
    @discardableResult
    public func update(_ predicate: UAActionPredicate?, forEntryWithName name: String) -> Bool {
        var result = false
        lock.sync {
            if let entry = registryEntry(name) {
                entry._predicate = predicate
                result = true
            }
        }
        return result
    }

    /**
     * Updates an entry's action.
     * - Parameters:
     *   - action: The action.
     *   - name: The name of the entry.
     * - Returns: The entry if found, otherwise null.
     */
    @objc(updateAction:forEntryWithName:)
    @discardableResult
    public func update(_ action: Action, forEntryWithName name: String) -> Bool {
        var result = false
        lock.sync {
            if let entry = registryEntry(name) {
                entry._action = action
                result = true
            }
        }
        return result
    }

    /**
     * Updates an entry's action.
     * - Parameters:
     *   - actionClass: The action class.
     *   - name: The name of the entry.
     * - Returns: The entry if found, otherwise null.
     */
    @objc(updateActionClass:forEntryWithName:)
    @discardableResult
    public func update(_ actionClass: AnyClass, forEntryWithName name: String) -> Bool {
        guard actionClass is Action.Type else {
            AirshipLogger.error("Unable to register an action class that isn't a subclass of UAAction.")
            return false
        }
        
        guard let actionClass = actionClass as? NSObject.Type else {
            AirshipLogger.error("Unable to register an action class that isn't a subclass of NSObject.")
            return false
        }
        
        var result = false
        lock.sync {
            if let entry = registryEntry(name) {
                entry._action = nil
                entry._actionClass = actionClass
                result = true
            }
        }
        return result
    }
    
    /**
     * Registers actions from a plist file.
     * - Parameters:
     *   - path: The path to the plist.
     */
    @objc(registerActionsFromFile:)
    public func registerActions(_ path: String) {
        AirshipLogger.debug("Loading actions from \(path)")
        guard let actions = NSArray(contentsOfFile: path) as? [[AnyHashable : Any]] else {
            AirshipLogger.error("Unable to load actions from: \(path)")
            return
        }
        
        
        for actionEntry in actions {
            guard let names = actionEntry[ActionRegistry.namesKey] as? [String], !names.isEmpty else {
                AirshipLogger.error("Missing action names for entry \(actionEntry)")
                continue
            }
            
            guard let actionClassName = actionEntry[ActionRegistry.actionKey] as? String else {
                AirshipLogger.error("Missing action class name for entry \(actionEntry)")
                continue
            }
            
            guard let actionClass = NSClassFromString(actionClassName) else {
                AirshipLogger.error("Unable to find class for name \(actionClassName)")
                continue
            }
            
            var predicateBlock: ((ActionArguments) -> Bool)? = nil
            if let predicateClassName = actionEntry[ActionRegistry.predicateKey] as? String {
                guard let predicateClass = NSClassFromString(predicateClassName) as? NSObject.Type else {
                    AirshipLogger.error("Unable to find class for name \(predicateClassName)")
                    continue
                }
                
                guard predicateClass is ActionPredicateProtocol.Type else {
                    AirshipLogger.error("Invalid predicate for class \(predicateClassName)")
                    continue
                }

                if let predicate = predicateClass.init() as? ActionPredicateProtocol {
                    predicateBlock = { args in
                        return predicate.apply(args)
                    }
                }
            }
            
            _ = self.register(actionClass, names: names, predicate: predicateBlock)
        }
    }
    
    private func register(_ entry: ActionRegistryEntry, names: [String], predicate: UAActionPredicate?) -> Bool {
        guard !names.isEmpty else {
            AirshipLogger.error("Unable to register action class. A name must be specified.")
            return false
        }
        
        lock.sync {
            self.removeNames(names)
            
            entry._names = names
            entry._predicate = predicate
            _entries.append(entry)
        }
        
        return true
    }

    func registerDefaultActions() {
        #if os(tvOS)
        let path = AirshipCoreResources.bundle.path(forResource: "UADefaultActionsTVOS", ofType: "plist")
        #else
        let path = AirshipCoreResources.bundle.path(forResource: "UADefaultActions", ofType: "plist")
        #endif

        if let path = path {
            registerActions(path)
        }
    }
}

/**
 * An action registry entry.
 */
@objc(UAActionRegistryEntry)
public class ActionRegistryEntry : NSObject {
    internal var _actionClass: NSObject.Type?
    internal var _situationOverrides: [Situation : Action] = [:]
    internal var _action : Action?

    internal var _names: [String] = []

    /**
     * The entry's names.
     */
    @objc
    public var names: [String] {
        get {
            return self._names
        }
    }
    
    internal var _predicate: UAActionPredicate?

    /**
     * The entry's predicate.
     */
    @objc
    public var predicate : UAActionPredicate? {
        get {
            return self._predicate
        }
    }
    
    /**
     * The entry's default action..
     */
    @objc
    public var action: Action {
        get {
            if (self._action == nil) {
                self._action = self._actionClass?.init() as? Action ?? EmptyAction()
            }
            return self._action!
        }
    }

    init(actionClass: NSObject.Type) {
        self._actionClass = actionClass
    }


    init(action: Action) {
        self._action = action
    }
    
    /**
     * Gets the action for the situation.
     * - Parameters:
     *   - situation: The situation.
     * - Returns: The action.
     */
    @objc(actionForSituation:)
    public func action(situation: Situation) -> Action {
        return self._situationOverrides[situation] ?? self.action
    }
}
