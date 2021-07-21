/* Copyright Airship and Contributors */

import Foundation

/**
 * Contact delegate to handle conflicts.
 */
@objc(UAContactConflictDelegate)
public protocol ContactConflictDelegate  {
    
    /**
     * Called when an anonymous user data will be lost due to the device being associated to an existing contact or
     * when the device is associated to a contact outside of the SDK.
     *
     * - Parameters:
     *   - anonymousContactData: The anonymous contact data.
     *   - namedUserID: The named user ID.
     */
    @objc(onConflictWithAnonymousContactData:namedUserID:)
    func onConflict(anonymousContactData: ContactData, namedUserID: String?)
}
