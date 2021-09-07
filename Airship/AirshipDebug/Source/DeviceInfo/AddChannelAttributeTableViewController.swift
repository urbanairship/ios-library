/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(Airship)
import Airship
#endif

class AddChannelAttributeTableViewController: AddAttributeTableViewController {

    override internal func applyMutations(_ mutations : AttributeMutations) {
        Airship.channel.apply(mutations)
    }

}
