/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

enum AirshipDebugAudienceSubject {
    case channel
    case contact

    func editTagGroups(_ editorBlock: (TagGroupsEditor) -> Void) {
        switch(self) {
        case .channel: Airship.channel.editTagGroups(editorBlock)
        case .contact: Airship.channel.editTagGroups(editorBlock)
        }
    }

    func editAttributes(_ editorBlock: (AttributesEditor) -> Void) {
        switch(self) {
        case .channel: Airship.channel.editAttributes(editorBlock)
        case .contact: Airship.channel.editAttributes(editorBlock)
        }
    }
}
