/* Copyright Airship and Contributors */

import Foundation


#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppPagerCompletedEvent: InAppEvent {
    let name = EventType.inAppPagerCompleted
    let data: (Sendable&Encodable)?

    init(pagerInfo: ThomasPagerInfo) {
        self.data = PagerCompletedData(
            identifier: pagerInfo.identifier,
            pageIndex: pagerInfo.pageIndex,
            pageCount: pagerInfo.pageCount,
            pageIdentifier: pagerInfo.pageIdentifier
        )
    }

    private struct PagerCompletedData: Encodable, Sendable {
        var identifier: String
        var pageIndex: Int
        var pageCount: Int
        var pageIdentifier: String

        enum CodingKeys: String, CodingKey {
            case identifier = "pager_identifier"
            case pageIndex = "page_index"
            case pageCount = "page_count"
            case pageIdentifier = "page_identifier"
        }
    }
}
