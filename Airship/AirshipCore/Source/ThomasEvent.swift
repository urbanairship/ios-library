/* Copyright Airship and Contributors */

import Foundation

/// - Note: for internal use only.  :nodoc:
public enum ThomasReportingEvent: Sendable {
    case buttonTap(ButtonTapEvent, ThomasLayoutContext)
    case formDisplay(FormDisplayEvent, ThomasLayoutContext)
    case formResult(FormResultEvent, ThomasLayoutContext)
    case gesture(GestureEvent, ThomasLayoutContext)
    case pageAction(PageActionEvent, ThomasLayoutContext)
    case pagerCompleted(PagerCompletedEvent, ThomasLayoutContext)
    case pageSwipe(PageSwipeEvent, ThomasLayoutContext)
    case pageView(PageViewEvent, ThomasLayoutContext)
    case pagerSummary(PagerSummaryEvent, ThomasLayoutContext)
    case dismiss(DismissEvent, TimeInterval, ThomasLayoutContext)

    public enum DismissEvent: Sendable {
        case buttonTapped(identifier: String, description: String)
        case timedOut
        case userDismissed
    }

    public struct PageViewEvent: Encodable, Sendable {
        public var identifier: String
        public var pageIdentifier: String
        public var pageIndex: Int
        public var pageViewCount: Int
        public var pageCount: Int
        public var completed: Bool


        public init(identifier: String, pageIdentifier: String, pageIndex: Int, pageViewCount: Int, pageCount: Int, completed: Bool) {
            self.identifier = identifier
            self.pageIdentifier = pageIdentifier
            self.pageIndex = pageIndex
            self.pageViewCount = pageViewCount
            self.pageCount = pageCount
            self.completed = completed
        }

        enum CodingKeys: String, CodingKey {
            case identifier = "pager_identifier"
            case pageIndex = "page_index"
            case pageCount = "page_count"
            case pageViewCount = "viewed_count"
            case pageIdentifier = "page_identifier"
            case completed
        }
    }

    public struct PagerCompletedEvent: Encodable, Sendable {
        public var identifier: String
        public var pageIndex: Int
        public var pageCount: Int
        public var pageIdentifier: String

        public init(identifier: String, pageIndex: Int, pageCount: Int, pageIdentifier: String) {
            self.identifier = identifier
            self.pageIndex = pageIndex
            self.pageCount = pageCount
            self.pageIdentifier = pageIdentifier
        }

        enum CodingKeys: String, CodingKey {
            case identifier = "pager_identifier"
            case pageIndex = "page_index"
            case pageCount = "page_count"
            case pageIdentifier = "page_identifier"
        }
    }

    public struct PageSwipeEvent: Encodable, Sendable {
        public var identifier: String
        public var toPageIndex: Int
        public var toPageIdentifier: String
        public var fromPageIndex: Int
        public var fromPageIdentifier: String

        public init(identifier: String, toPageIndex: Int, toPageIdentifier: String, fromPageIndex: Int, fromPageIdentifier: String) {
            self.identifier = identifier
            self.toPageIndex = toPageIndex
            self.toPageIdentifier = toPageIdentifier
            self.fromPageIndex = fromPageIndex
            self.fromPageIdentifier = fromPageIdentifier
        }

        enum CodingKeys: String, CodingKey {
            case identifier = "pager_identifier"
            case toPageIndex = "to_page_index"
            case toPageIdentifier = "to_page_identifier"
            case fromPageIndex = "from_page_index"
            case fromPageIdentifier = "from_page_identifier"
        }
    }

    public struct GestureEvent: Encodable, Sendable {
        public var identifier: String
        public var reportingMetadata: AirshipJSON?

        public init(identifier: String, reportingMetadata: AirshipJSON? = nil) {
            self.identifier = identifier
            self.reportingMetadata = reportingMetadata
        }

        enum CodingKeys: String, CodingKey {
            case identifier = "gesture_identifier"
            case reportingMetadata = "reporting_metadata"
        }
    }

    public struct PageActionEvent: Encodable, Sendable {
        public var identifier: String
        public var reportingMetadata: AirshipJSON?

        public init(identifier: String, reportingMetadata: AirshipJSON? = nil) {
            self.identifier = identifier
            self.reportingMetadata = reportingMetadata
        }

        enum CodingKeys: String, CodingKey {
            case identifier = "action_identifier"
            case reportingMetadata = "reporting_metadata"
        }
    }

    public struct ButtonTapEvent: Encodable, Sendable {
        public var identifier: String
        public var reportingMetadata: AirshipJSON?

        public init(identifier: String, reportingMetadata: AirshipJSON? = nil) {
            self.identifier = identifier
            self.reportingMetadata = reportingMetadata
        }

        enum CodingKeys: String, CodingKey {
            case identifier = "button_identifier"
            case reportingMetadata = "reporting_metadata"
        }
    }

    public struct FormResultEvent: Encodable, Sendable {
        public var forms: AirshipJSON

        public init(forms: AirshipJSON) {
            self.forms = forms
        }
    }

    public struct FormDisplayEvent: Encodable, Sendable {
        public var identifier: String
        public var formType: String
        public var responseType: String?

        public init(identifier: String, formType: String, responseType: String? = nil) {
            self.identifier = identifier
            self.formType = formType
            self.responseType = responseType
        }
        
        enum CodingKeys: String, CodingKey {
            case identifier = "form_identifier"
            case formType = "form_type"
            case responseType = "form_response_type"
        }
    }

    public struct PagerSummaryEvent: Encodable, Sendable, Equatable, Hashable {
        public var identifier: String
        public var viewedPages: [PageView]
        public var pageCount: Int
        public var completed: Bool

        public init(identifier: String, viewedPages: [PageView], pageCount: Int, completed: Bool) {
            self.identifier = identifier
            self.viewedPages = viewedPages
            self.pageCount = pageCount
            self.completed = completed
        }

        enum CodingKeys: String, CodingKey {
            case identifier = "pager_identifier"
            case viewedPages = "viewed_pages"
            case pageCount = "page_count"
            case completed = "completed"
        }

        public struct PageView: Encodable, Sendable, Equatable, Hashable {
            public var identifier: String
            public var index: Int
            public var displayTime: TimeInterval

            public init(identifier: String, index: Int, displayTime: TimeInterval) {
                self.identifier = identifier
                self.index = index
                self.displayTime = displayTime
            }

            enum CodingKeys: String, CodingKey {
                case identifier = "page_identifier"
                case index = "page_index"
                case displayTime = "display_time"
            }

            public func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(self.identifier, forKey: .identifier)
                try container.encode(self.index, forKey: .index)

                try container.encode(
                    String(format: "%.2f", displayTime),
                    forKey: .displayTime
                )
            }
        }
    }
}
