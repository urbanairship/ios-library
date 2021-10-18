/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

class AddNamedUserAttributeTableViewController: AddAttributeTableViewController {
    
    override open func editAttributes(editorBlock: (AttributesEditor) -> Void) {
        Airship.contact.editAttributes(editorBlock)
    }
    
}
