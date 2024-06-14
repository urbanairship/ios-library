/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppPageViewEvent: InAppEvent {
    let name = EventType.inAppPageView
    let data: (Sendable&Encodable)?

    init(pagerInfo: ThomasPagerInfo, viewCount: Int) {
        self.data = PageViewData(
            identifier: pagerInfo.identifier,
            pageCount: pagerInfo.pageCount,
            completed: pagerInfo.completed,
            pageViewCount: viewCount,
            pageIdentifier: pagerInfo.pageIdentifier,
            pageIndex: pagerInfo.pageIndex
        )
    }

    private struct PageViewData: Encodable, Sendable {
        var identifier: String
        var pageCount: Int
        var completed: Bool
        var pageViewCount: Int
        var pageIdentifier: String
        var pageIndex: Int


        enum CodingKeys: String, CodingKey {
            case identifier = "pager_identifier"
            case pageIndex = "page_index"
            case pageCount = "page_count"
            case pageViewCount = "viewed_count"
            case pageIdentifier = "page_identifier"
            case completed
        }
    }
}

