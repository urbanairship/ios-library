/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(Airship)
import Airship
#endif

class AddNamedUserAttributeTableViewController: AddAttributeTableViewController {
    
    override open func editAttributes(editorBlock: (AttributesEditor) -> Void) {
        Airship.contact.editAttributes(editorBlock)
    }
    
}
