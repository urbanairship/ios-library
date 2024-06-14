/* Copyright Airship and Contributors */

import Foundation


#if canImport(AirshipCore)
import AirshipCore
#endif


struct InAppPageSwipeEvent: InAppEvent {
    let name = EventType.inAppPageSwipe
    let data: (Sendable&Encodable)?

    init(from: ThomasPagerInfo, to: ThomasPagerInfo) {
        self.data = PagerSwipeData(
            identifier: from.identifier,
            toPageIndex: to.pageIndex,
            toPageIdentifier: to.pageIdentifier,
            fromPageIndex: from.pageIndex,
            fromPageIdentifier: from.pageIdentifier
        )
    }

    private struct PagerSwipeData: Encodable, Sendable {
        var identifier: String
        var toPageIndex: Int
        var toPageIdentifier: String
        var fromPageIndex: Int
        var fromPageIdentifier: String

        enum CodingKeys: String, CodingKey {
            case identifier = "pager_identifier"
            case toPageIndex = "to_page_index"
            case toPageIdentifier = "to_page_identifier"
            case fromPageIndex = "from_page_index"
            case fromPageIdentifier = "from_page_identifier"
        }
    }
}
