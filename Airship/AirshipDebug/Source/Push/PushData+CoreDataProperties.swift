/* Copyright Airship and Contributors */

import Foundation
public import CoreData

//Had to generate it manually as coredata codegen doesn't work well with swift 6
extension PushData {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PushData> {
        return NSFetchRequest<PushData>(entityName: "PushData")
    }

    @NSManaged public var alert: String?
    @NSManaged public var data: String?
    @NSManaged public var pushID: String?
    @NSManaged public var time: Double

}
