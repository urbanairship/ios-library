/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

struct PageViewSummary: Encodable, Sendable, Equatable {
    let identifier: String
    let index: Int
    let displayTime: TimeInterval

    enum CodingKeys: String, CodingKey {
        case identifier = "page_identifier"
        case index = "page_index"
        case displayTime = "display_time"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.identifier, forKey: .identifier)
        try container.encode(self.index, forKey: .index)
        
        try container.encode(
            String(format: "%.2f", displayTime),
            forKey: .displayTime
        )

    }
}

struct InAppPagerSummaryEvent: InAppEvent {
    let name = EventType.inAppPagerSummary
    let data: (any Sendable & Encodable)?

    init(pagerInfo: ThomasPagerInfo, viewedPages: [PageViewSummary]) {
        self.data = PagerSummaryData(
            identifier: pagerInfo.identifier,
            viewedPages: viewedPages,
            pageCount: pagerInfo.pageCount,
            completed: pagerInfo.completed
        )
    }

    private struct PagerSummaryData: Encodable, Sendable {
        var identifier: String
        var viewedPages: [PageViewSummary]
        var pageCount: Int
        var completed: Bool

        enum CodingKeys: String, CodingKey {
            case identifier = "pager_identifier"
            case viewedPages = "viewed_pages"
            case pageCount = "page_count"
            case completed = "completed"
        }
    }
}


