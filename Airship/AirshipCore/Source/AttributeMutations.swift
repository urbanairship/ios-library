/* Copyright Airship and Contributors */

import Foundation


/**
 * Defines attributes mutations.
 */
@available(*, deprecated, message: "Use Contact#editAttributes() or Channel#editAttributes() instead.")
@objc(UAAttributeMutations)
public class AttributeMutations : NSObject {
    
    var mutations: [Mutation] = []
    
    /**
     * Sets an attribute.
     * - Parameters:
     *   - string: The value.
     *   - forAttribute: The attribute
     */
    @objc(setString:forAttribute:)
    public func setString(_ string: String, forAttribute: String) {
        mutations.append(Mutation(attribute: forAttribute, apply: { editor in
            editor.set(string: string, attribute: forAttribute)
        }))
    }
    
    /**
     * Sets an attribute.
     * - Parameters:
     *   - number: The value.
     *   - forAttribute: The attribute
     */
    @objc(setNumber:forAttribute:)
    public func setNumber(_ number: NSNumber, forAttribute: String) {
        mutations.append(Mutation(attribute: forAttribute, apply: { editor in
            editor.set(number: number, attribute: forAttribute)
        }))
    }
    
    /**
     * Sets an attribute.
     * - Parameters:
     *   - date: The value.
     *   - forAttribute: The attribute
     */
    @objc(setDate:forAttribute:)
    public func setDate(_ date: Date, forAttribute: String) {
        mutations.append(Mutation(attribute: forAttribute, apply: { editor in
            editor.set(date: date, attribute: forAttribute)
        }))
    }
    
    /**
     * Removes an attribute.
     * - Parameters:
     *   - attribute: The attribute
     */
    @objc(removeAttribute:)
    public func removeAttribute(_ attribute: String) {
        mutations.append(Mutation(attribute: attribute, apply: { editor in
            editor.remove(attribute)
        }))
    }
    
    /**
     * Generates an empty mutation.
     * - Returns: An empty mutation object.
     */
    @objc
    public class func mutations() -> AttributeMutations {
        return AttributeMutations()
    }
    
    // NOTE: For internal use only. :nodoc:
    @objc
    public func applyMutations(editor: AttributesEditor) {
        mutations.forEach { $0.apply(editor) }
    }
}

internal struct Mutation {
    let attribute: String
    let apply : (AttributesEditor) -> Void
}


