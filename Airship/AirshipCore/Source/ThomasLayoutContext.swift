/* Copyright Airship and Contributors */

import Foundation

/// - Note: for internal use only.  :nodoc:
public struct ThomasLayoutContext: Encodable, Equatable, Sendable {
    public struct Pager: Encodable, Equatable, Sendable {
        public var identifier: String
        public var pageIdentifier: String
        public var pageIndex: Int
        public var completed: Bool
        public var count: Int
        public var pageHistory: [ThomasViewedPageInfo] = []

        public init(
            identifier: String,
            pageIdentifier: String,
            pageIndex: Int,
            completed: Bool,
            count: Int,
            pageHistory: [ThomasViewedPageInfo] = []
        ) {
            self.identifier = identifier
            self.pageIdentifier = pageIdentifier
            self.pageIndex = pageIndex
            self.completed = completed
            self.count = count
            self.pageHistory = pageHistory
        }

        enum CodingKeys: String, CodingKey {
            case identifier
            case pageIdentifier = "page_identifier"
            case pageIndex = "page_index"
            case completed
            case count
            case pageHistory = "page_history"
        }
    }

    public struct Form: Encodable, Equatable, Sendable {
        public var identifier: String
        public var submitted: Bool
        public var type: String
        public var responseType: String?

        public init(identifier: String, submitted: Bool, type: String, responseType: String? = nil) {
            self.identifier = identifier
            self.submitted = submitted
            self.type = type
            self.responseType = responseType
        }

        enum CodingKeys: String, CodingKey {
            case identifier
            case submitted
            case type
            case responseType = "response_type"
        }
    }

    public struct Button: Encodable, Equatable, Sendable {
        public var identifier: String

        public init(identifier: String) {
            self.identifier = identifier
        }

        enum CodingKeys: String, CodingKey {
            case identifier
        }
    }

    public var pager: Pager?
    public var button: Button?
    public var form: Form?

    public init(pager: Pager? = nil, button: Button? = nil, form: Form? = nil) {
        self.pager = pager
        self.button = button
        self.form = form
    }
}
