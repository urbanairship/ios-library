/* Copyright Airship and Contributors */

import Foundation

/// Defines attributes mutations.
@available(
    *,
    deprecated,
    message: "Use Contact#editAttributes() or Channel#editAttributes() instead."
)
public class AttributeMutations: NSObject {

    var mutations: [Mutation] = []

    /**
     * Sets an attribute.
     * - Parameters:
     *   - string: The value.
     *   - forAttribute: The attribute
     */
    public func setString(_ string: String, forAttribute: String) {
        mutations.append(
            Mutation(
                attribute: forAttribute,
                apply: { editor in
                    editor.set(string: string, attribute: forAttribute)
                }
            )
        )
    }

    /**
     * Sets an attribute.
     * - Parameters:
     *   - number: The value.
     *   - forAttribute: The attribute
     */
    public func setNumber(_ number: NSNumber, forAttribute: String) {
        mutations.append(
            Mutation(
                attribute: forAttribute,
                apply: { editor in
                    editor.set(number: number, attribute: forAttribute)
                }
            )
        )
    }

    /**
     * Sets an attribute.
     * - Parameters:
     *   - date: The value.
     *   - forAttribute: The attribute
     */
    public func setDate(_ date: Date, forAttribute: String) {
        mutations.append(
            Mutation(
                attribute: forAttribute,
                apply: { editor in
                    editor.set(date: date, attribute: forAttribute)
                }
            )
        )
    }

    /**
     * Removes an attribute.
     * - Parameters:
     *   - attribute: The attribute
     */
    public func removeAttribute(_ attribute: String) {
        mutations.append(
            Mutation(
                attribute: attribute,
                apply: { editor in
                    editor.remove(attribute)
                }
            )
        )
    }

    /**
     * Generates an empty mutation.
     * - Returns: An empty mutation object.
     */
    public class func mutations() -> AttributeMutations {
        return AttributeMutations()
    }

    /// NOTE: For internal use only. :nodoc:
    public func applyMutations(editor: AttributesEditor) {
        mutations.forEach { $0.apply(editor) }
    }
}

internal struct Mutation {
    let attribute: String
    let apply: (AttributesEditor) -> Void
}
