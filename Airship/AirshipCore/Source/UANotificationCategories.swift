// Copyright Airship and Contributors

import Foundation

/**
 * Utility methods to create categories from plist files or NSDictionaries.
 */
@objc
public class UANotificationCategories : NSObject {
    // MARK: - Notification Categories Factories

    /**
     * Factory method to create the default set of user notification categories.
     * Background user notification actions will default to requiring authorization.
     * - Returns: A set of user notification categories
     */
    @objc
    public class func defaultCategories() -> Set<UANotificationCategory> {
        return self.defaultCategories(withRequireAuth: true)
    }

    /**
     * Factory method to create the default set of user notification categories.
     *
     * - Parameter requireAuth: If background actions should default to requiring authorization or not.
     * - Returns: A set of user notification categories.
     */
    @objc
    public class func defaultCategories(withRequireAuth requireAuth: Bool) -> Set<UANotificationCategory> {
        guard let path = UAirshipCoreResources.bundle.path(forResource: "UANotificationCategories", ofType: "plist") else {
            return []
        }

        return self.createCategories(fromFile: path, requireAuth: requireAuth)
    }

    /**
     * Creates a set of categories from the specified `.plist` file.
     *
     * Categories are defined in a plist dictionary with the category ID
     * followed by an NSArray of user notification action definitions. The
     * action definitions use the same keys as the properties on the action,
     * with the exception of "foreground" mapping to either UIUserNotificationActivationModeForeground
     * or UIUserNotificationActivationModeBackground. The required action definition
     * title can be defined with either the "title" or "title_resource" key, where
     * the latter takes precedence. If "title_resource" does not exist, the action
     * definition title will fall back to the value of "title". If the required action
     * definition title is not defined, the category will not be created.
     *
     * Example:
     *
     *  {
     *      "category_id" : [
     *          {
     *              "identifier" : "action ID",
     *              "title_resource" : "action title resource",
     *              "title" : "action title",
     *              "foreground" : @YES,
     *              "authenticationRequired" : @NO,
     *              "destructive" : @NO
     *          }]
     *  }
     *
     * - Parameter path: The path of the `plist` file
     * - Returns: A set of categories
     */
    @objc
    public class func createCategories(fromFile path: String) -> Set<UANotificationCategory> {
        return self.createCategories(fromFile: path, actionDefinitionModBlock: { _ in })
    }

    /**
     * Creates a user notification category with the specified ID and action definitions.
     *
     * - Parameter categoryId: The category identifier
     * - Parameter actionDefinitions: An array of user notification action dictionaries used to construct UANotificationAction for the category.
     * - Returns: The user notification category created, or `nil` if an error occurred.
     */
    @objc
    public class func createCategory(_ categoryId: String, actions actionDefinitions: [[AnyHashable : Any]]) -> UANotificationCategory? {
        guard let actions = self.getActionsFromActionDefinitions(actionDefinitions) else {
            return nil
        }

        return UANotificationCategory(
            identifier: categoryId,
            actions: actions,
            intentIdentifiers: [],
            options: [])
    }

    /**
     * Creates a user notification category with the specified ID, action definitions, and
     * hiddenPreviewsBodyPlaceholder.
     *
     * - Parameter categoryId: The category identifier
     * - Parameter actionDefinitions: An array of user notification action dictionaries used to construct UANotificationAction for the category.
     * - Parameter hiddenPreviewsBodyPlaceholder: A placeholder string to display when the user has disabled notification previews for the app.
     * - Returns: The user notification category created or `nil` if an error occurred.
     */
    @objc
    public class func createCategory(_ categoryId: String, actions actionDefinitions: [[AnyHashable : Any]], hiddenPreviewsBodyPlaceholder: String) -> UANotificationCategory? {

        guard let actions = self.getActionsFromActionDefinitions(actionDefinitions) else {
            return nil
        }

        return UANotificationCategory(
            identifier: categoryId,
            actions: actions,
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: hiddenPreviewsBodyPlaceholder,
            options: [])
    }

    private class func createCategories(fromFile path: String, requireAuth: Bool) -> Set<UANotificationCategory> {
        return self.createCategories(fromFile: path, actionDefinitionModBlock: { actionDefinition in
            if actionDefinition["foreground"] as? Bool == false {
                actionDefinition["authenticationRequired"] = requireAuth
            }
        })
    }

    private class func createCategories(fromFile path: String, actionDefinitionModBlock: @escaping (inout [AnyHashable : Any]) -> Void) -> Set<UANotificationCategory> {

        let categoriesDictionary = NSDictionary(contentsOfFile: path) as? Dictionary ?? [:]
        var categories: Set<UANotificationCategory> = []

        for key in categoriesDictionary.keys {
            guard let categoryId = key as? String else {
                continue
            }

            guard var actions = categoriesDictionary[categoryId] as? [[AnyHashable : Any]] else {
                continue
            }

            if (actions.count == 0) {
                continue
            }

            var mutableActions: [[AnyHashable : Any]] = []

            for actionDef in actions {
                var mutableActionDef: [AnyHashable : Any] = actionDef as [AnyHashable : Any]
                actionDefinitionModBlock(&mutableActionDef)
                mutableActions.append(mutableActionDef)
            }

            actions = mutableActions

            if let category = self.createCategory(categoryId, actions: actions) {
                categories.insert(category)
            }
        }

        return categories
    }

    private class func getTitle(_ actionDefinition: [AnyHashable :Any]) -> String? {
        guard let title = actionDefinition["title"] as? String else {
            return nil
        }
        if let titleResource = actionDefinition["title_resource"] as? String {
            let localizedTitle = titleResource.localizedString(withTable: "UrbanAirship",
                                                               moduleBundle: UAirshipCoreResources.bundle,
                                                               defaultValue: title)

            if localizedTitle == title {
                return titleResource.localizedString(withTable: "AirshipAccengage",
                                                     moduleBundle: UAirshipCoreResources.bundle,
                                                     defaultValue: title)
            }
        }

        return title
    }

    private class func getActionsFromActionDefinitions(_ actionDefinitions: [[AnyHashable : Any]]) -> [UANotificationAction]? {
        var actions: [UANotificationAction] = []

        for actionDefinition in actionDefinitions {
            guard let actionId = actionDefinition["identifier"] as? String else {
                AirshipLogger.error("Error creating action from definition: \(actionDefinition) due to missing identifier.")
                return nil
            }

            guard let title = getTitle(actionDefinition) else {
                AirshipLogger.error("Error creating action: \(actionId) due to missing title.")
                return nil
            }

            var options: UANotificationActionOptions = []

            if actionDefinition["destructive"] as? Bool == true {
                options.insert(.destructive)
            }

            if actionDefinition["foreground"] as? Bool == true {
                options.insert(.foreground)
            }

            if actionDefinition["authenticationRequired"] as? Bool == true {
                options.insert(.authenticationRequired)
            }

            if actionDefinition["action_type"] as? String == "text_input" {
                guard let textInputButtonTitle = actionDefinition["text_input_button_title"] as? String else {
                    AirshipLogger.error("Error creating action: \(actionId) due to missing text input button title.")
                    return nil
                }
                guard let textInputPlaceholder = actionDefinition["text_input_placeholder"] as? String else {
                    AirshipLogger.error("Error creating action: \(actionId) due to missing text input placeholder.")
                    return nil
                }

                actions.append(UATextInputNotificationAction(identifier: actionId,
                                                             title: title,
                                                             textInputButtonTitle: textInputButtonTitle,
                                                             textInputPlaceholder: textInputPlaceholder,
                                                             options: options))
            } else {
                actions.append(UANotificationAction(identifier: actionId, title: title, options: options))
            }
        }

        return actions
    }
}
