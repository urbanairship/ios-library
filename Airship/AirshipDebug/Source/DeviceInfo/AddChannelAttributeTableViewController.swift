/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

class AddChannelAttributeTableViewController: AddAttributeTableViewController {
    
    override open func editAttributes(editorBlock: (AttributesEditor) -> Void) {
        Airship.channel.editAttributes(editorBlock)
    }

}
