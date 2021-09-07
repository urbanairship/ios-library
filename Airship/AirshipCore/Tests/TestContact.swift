import Foundation

@testable
import AirshipCore

@objc(UATestContact)
public class TestContact : NSObject, ContactProtocol, UAComponent {
    public var isComponentEnabled: Bool = true
    
    public var namedUserID: String?
    
    public var pendingAttributeUpdates: [AttributeUpdate] = []
    
    public var pendingTagGroupUpdates: [TagGroupUpdate] = []
    
    @objc
    public var tagGroupEditor : TagGroupsEditor?
    
    @objc
    public var attributeEditor : AttributesEditor?
    
    public func identify(_ namedUserID: String) {
        self.namedUserID = namedUserID
    }
    
    public func reset() {
        self.namedUserID = nil
    }
    
    public func editTagGroups() -> TagGroupsEditor {
        return tagGroupEditor!
    }
    
    public func editAttributes() -> AttributesEditor {
        return attributeEditor!
    }
    
    public func editTagGroups(_ editorBlock: (TagGroupsEditor) -> Void) {
        let editor = editTagGroups()
        editorBlock(editor)
        editor.apply()
    }
    
    public func editAttributes(_ editorBlock: (AttributesEditor) -> Void) {
        let editor = editAttributes()
        editorBlock(editor)
        editor.apply()
    }

    
    
}
