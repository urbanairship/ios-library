/* Copyright Airship and Contributors */

public import Foundation
#if canImport(AirshipCore)
import AirshipCore
#endif

/// Provides an interface to the channel functionality.
@objc
public final class UAChannel: NSObject, Sendable {

    override init() {
        super.init()
    }

    @objc
    public var identifier: String? {
        return Airship.channel.identifier
    }

    /// Device tags
    @objc
    public var tags: [String] {
        get {
            return Airship.channel.tags
        }

        set {
            Airship.channel.tags = newValue
        }

    }

    @objc
    public func editTags() -> UATagEditor? {
        let tagEditor = UATagEditor()
        tagEditor.editor = Airship.channel.editTags()
        return tagEditor
    }

    @objc
    public func editTagGroups() -> UATagGroupsEditor {
        let tagGroupsEditor = UATagGroupsEditor()
        tagGroupsEditor.editor = Airship.channel.editTagGroups()
        return tagGroupsEditor
    }

    @objc
    public func editTagGroups(_ editorBlock: (UATagGroupsEditor) -> Void) {
        let editor = editTagGroups()
        editorBlock(editor)
        editor.apply()
    }

    @objc
    public func editSubscriptionLists() -> UASubscriptionListEditor {
        let subscriptionListEditor = UASubscriptionListEditor()
        subscriptionListEditor.editor = Airship.channel.editSubscriptionLists()
        return subscriptionListEditor
    }

    @objc
    public func editSubscriptionLists(_ editorBlock: (UASubscriptionListEditor) -> Void) {
        let editor = editSubscriptionLists()
        editorBlock(editor)
        editor.apply()
    }

    @objc
    public func fetchSubscriptionLists() async throws -> [String] {
        try await Airship.channel.fetchSubscriptionLists()
    }

    /// Fetches current subscription lists.
    /// - Parameter completionHandler: The completion handler with the subscription lists or an error.
    @objc(fetchSubscriptionListsWithCompletion:)
    public func fetchSubscriptionLists(completionHandler: @escaping @Sendable ([String]?, (any Error)?) -> Void) {
        Task {
            do {
                let subscriptionLists = try await Airship.channel.fetchSubscriptionLists()
                completionHandler(subscriptionLists, nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }

    @objc
    public func editAttributes() -> UAAttributesEditor {
        let attributesEditor =  UAAttributesEditor()
        attributesEditor.editor = Airship.channel.editAttributes()
        return attributesEditor
    }

    @objc
    public func editAttributes(_ editorBlock: (UAAttributesEditor) -> Void) {
        let editor = editAttributes()
        editorBlock(editor)
        editor.apply()
    }

    @objc(enableChannelCreation)
    public func enableChannelCreation() {
        Airship.channel.enableChannelCreation()
    }

}
