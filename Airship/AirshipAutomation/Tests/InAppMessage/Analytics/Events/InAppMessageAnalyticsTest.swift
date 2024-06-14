/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipAutomation
@testable import AirshipCore

class InAppMessageAnalyticsTest: XCTestCase {

    private let eventRecorder = EventRecorder()
    private let historyStore = TestDisplayHistoryStore()
    private let preparedInfo = PreparedScheduleInfo(
        scheduleID: UUID().uuidString,
        productID: UUID().uuidString,
        campaigns: AirshipJSON.string(UUID().uuidString),
        contactID: UUID().uuidString,
        experimentResult: ExperimentResult(
            channelID: UUID().uuidString,
            contactID: UUID().uuidString,
            isMatch: true,
            reportingMetadata: [AirshipJSON.string(UUID().uuidString)]
        ),
        reportingContext: AirshipJSON.string(UUID().uuidString),
        triggerSessionID: UUID().uuidString
    )

    @MainActor
    func testSource() async throws {
        let analytics = InAppMessageAnalytics(
            preparedScheduleInfo: preparedInfo,
            message: InAppMessage(
                name: "name",
                displayContent: .custom(.string("custom")),
                source: .remoteData
            ),
            displayImpressionRule: .once,
            eventRecorder: eventRecorder,
            historyStore: historyStore, 
            displayHistory: MessageDisplayHistory()
        )

        analytics.recordEvent(TestInAppEvent(), layoutContext: nil)

        let data = eventRecorder.eventData.first!
        XCTAssertEqual(
            data.messageID,
            .airship(
                identifier: self.preparedInfo.scheduleID,
                campaigns: self.preparedInfo.campaigns
            )
        )
        XCTAssertEqual(data.source, .airship)
    }

    @MainActor
    func testAppDefined() async throws {
        let analytics = InAppMessageAnalytics(
            preparedScheduleInfo: preparedInfo,
            message: InAppMessage(
                name: "name",
                displayContent: .custom(.string("custom")),
                source: .appDefined
            ),
            displayImpressionRule: .once,
            eventRecorder: eventRecorder,
            historyStore: historyStore,
            displayHistory: MessageDisplayHistory()
        )


        analytics.recordEvent(TestInAppEvent(), layoutContext: nil)

        let data = eventRecorder.eventData.first!
        XCTAssertEqual(
            data.messageID,
            .appDefined(
                identifier: self.preparedInfo.scheduleID
            )
        )
        XCTAssertEqual(data.source, .appDefined)
    }

    @MainActor
    func testLegacyMessageID() async throws {
        let analytics = InAppMessageAnalytics(
            preparedScheduleInfo: preparedInfo,
            message: InAppMessage(
                name: "name",
                displayContent: .custom(.string("custom")),
                source: .legacyPush
            ),
            displayImpressionRule: .once,
            eventRecorder: eventRecorder,
            historyStore: historyStore,
            displayHistory: MessageDisplayHistory()
        )

        analytics.recordEvent(TestInAppEvent(), layoutContext: nil)

        let data = eventRecorder.eventData.first!
        XCTAssertEqual(
            data.messageID,
            .legacy(
                identifier: self.preparedInfo.scheduleID
            )
        )
        XCTAssertEqual(data.source, .airship)
    }

    @MainActor
    func testData() async throws {
        let thomasLayoutContext  = ThomasLayoutContext(
            formInfo: ThomasFormInfo(
            identifier: UUID().uuidString,
            submitted: true,
            formType: UUID().uuidString,
            formResponseType: UUID().uuidString
            ),
            pagerInfo: ThomasPagerInfo(
                identifier: UUID().uuidString,
                pageIndex: 1,
                pageIdentifier: UUID().uuidString,
                pageCount: 2,
                completed: false
            ),
            buttonInfo: ThomasButtonInfo(identifier: UUID().uuidString)
        )

        let expectedContext = InAppEventContext.makeContext(
            reportingContext: preparedInfo.reportingContext,
            experimentsResult: preparedInfo.experimentResult,
            layoutContext: thomasLayoutContext,
            displayContext: .init(
                triggerSessionID: preparedInfo.triggerSessionID,
                isFirstDisplay: true,
                isFirstDisplayTriggerSessionID: true
            )
        )

        let analytics = InAppMessageAnalytics(
            preparedScheduleInfo: preparedInfo,
            message: InAppMessage(
                name: "name",
                displayContent: .custom(.string("custom")),
                source: .legacyPush,
                renderedLocale: AirshipJSON.string("rendered locale")
            ),
            displayImpressionRule: .once,
            eventRecorder: eventRecorder,
            historyStore: historyStore,
            displayHistory: MessageDisplayHistory()
        )


        analytics.recordEvent(TestInAppEvent(), layoutContext: thomasLayoutContext)

        let data = self.eventRecorder.eventData.first!
        XCTAssertEqual(data.context, expectedContext)
        XCTAssertEqual(data.renderedLocale, AirshipJSON.string("rendered locale"))
        XCTAssertEqual(data.event.name, EventType.customEvent)
    }
    
    @MainActor
    func testSingleImpression() async throws {
        let date = UATestDate(offset: 0, dateOverride: Date())
        
        let analytics = InAppMessageAnalytics(
            preparedScheduleInfo: preparedInfo,
            message: InAppMessage(
                name: "name",
                displayContent: .custom(.string("custom")),
                source: .legacyPush,
                renderedLocale: AirshipJSON.string("rendered locale")
            ),
            displayImpressionRule: .once,
            eventRecorder: eventRecorder,
            historyStore: historyStore,
            displayHistory: MessageDisplayHistory(),
            date: date
        )

        analytics.recordEvent(InAppDisplayEvent(), layoutContext: nil)

        
        let impression = try XCTUnwrap(eventRecorder.lastRecordedImpression)
        XCTAssertEqual(preparedInfo.scheduleID, impression.entityID)
        XCTAssertEqual(AirshipMeteredUsageType.inAppExperienceImpression, impression.usageType)
        XCTAssertEqual(preparedInfo.productID, impression.product)
        XCTAssertEqual(preparedInfo.reportingContext, impression.reportingContext)
        XCTAssertEqual(date.now, impression.timestamp)
        XCTAssertEqual(preparedInfo.contactID, impression.contactID)

        eventRecorder.lastRecordedImpression = nil
        analytics.recordEvent(InAppDisplayEvent(), layoutContext: nil)
        XCTAssertNil(eventRecorder.lastRecordedImpression)

        let displayHistory = await self.historyStore.get(
            scheduleID: preparedInfo.scheduleID
        )
        XCTAssertEqual(displayHistory.lastImpression?.date, date.now)
        XCTAssertEqual(displayHistory.lastImpression?.triggerSessionID, preparedInfo.triggerSessionID)
    }

    @MainActor
    func testImpressionInterval() async throws {
        let date = UATestDate(offset: 0, dateOverride: Date())

        let analytics = InAppMessageAnalytics(
            preparedScheduleInfo: preparedInfo,
            message: InAppMessage(
                name: "name",
                displayContent: .custom(.string("custom")),
                source: .legacyPush,
                renderedLocale: AirshipJSON.string("rendered locale")
            ),
            displayImpressionRule: .interval(10.0),
            eventRecorder: eventRecorder,
            historyStore: historyStore,
            displayHistory: MessageDisplayHistory(),
            date: date
        )

        analytics.recordEvent(InAppDisplayEvent(), layoutContext: nil)

        let impression = try XCTUnwrap(eventRecorder.lastRecordedImpression)
        XCTAssertEqual(preparedInfo.scheduleID, impression.entityID)
        XCTAssertEqual(AirshipMeteredUsageType.inAppExperienceImpression, impression.usageType)
        XCTAssertEqual(preparedInfo.productID, impression.product)
        XCTAssertEqual(preparedInfo.reportingContext, impression.reportingContext)
        XCTAssertEqual(date.now, impression.timestamp)
        XCTAssertEqual(preparedInfo.contactID, impression.contactID)

        eventRecorder.lastRecordedImpression = nil
        analytics.recordEvent(InAppDisplayEvent(), layoutContext: nil)
        XCTAssertNil(eventRecorder.lastRecordedImpression)

        var displayHistory = await self.historyStore.get(
            scheduleID: preparedInfo.scheduleID
        )
        XCTAssertEqual(displayHistory.lastImpression?.date, date.now)
        XCTAssertEqual(displayHistory.lastImpression?.triggerSessionID, preparedInfo.triggerSessionID)


        date.offset += 9.9
        analytics.recordEvent(InAppDisplayEvent(), layoutContext: nil)
        XCTAssertNil(eventRecorder.lastRecordedImpression)

        date.offset += 0.1
        analytics.recordEvent(InAppDisplayEvent(), layoutContext: nil)
        XCTAssertNotNil(eventRecorder.lastRecordedImpression)

        displayHistory = await self.historyStore.get(
            scheduleID: preparedInfo.scheduleID
        )
        XCTAssertEqual(displayHistory.lastImpression?.date, date.now)
        XCTAssertEqual(displayHistory.lastImpression?.triggerSessionID, preparedInfo.triggerSessionID)
    }

    @MainActor
    func testReportingDisabled() async throws {
        let analytics = InAppMessageAnalytics(
            preparedScheduleInfo: preparedInfo,
            message: InAppMessage(
                name: "name",
                displayContent: .custom(.string("custom")),
                source: .legacyPush,
                isReportingEnabled: false,
                renderedLocale: AirshipJSON.string("rendered locale")
            ),
            displayImpressionRule: .once,
            eventRecorder: eventRecorder,
            historyStore: historyStore,
            displayHistory: MessageDisplayHistory()
        )

        analytics.recordEvent(InAppDisplayEvent(), layoutContext: nil)
        XCTAssertTrue(self.eventRecorder.eventData.isEmpty)

        // impressions are still recorded
        XCTAssertNotNil(eventRecorder.lastRecordedImpression)
    }


    @MainActor
    func testDisplayUpdatesHistory() async {
        let analytics = InAppMessageAnalytics(
            preparedScheduleInfo: preparedInfo,
            message: InAppMessage(
                name: "name",
                displayContent: .custom(.string("custom")),
                source: .legacyPush,
                isReportingEnabled: true,
                renderedLocale: AirshipJSON.string("rendered locale")
            ),
            displayImpressionRule: .once,
            eventRecorder: eventRecorder,
            historyStore: historyStore,
            displayHistory: MessageDisplayHistory()
        )

        var displayHistory = await self.historyStore.get(
            scheduleID: preparedInfo.scheduleID
        )
        XCTAssertNil(displayHistory.lastDisplay?.triggerSessionID)


        displayHistory = await self.historyStore.get(
            scheduleID: preparedInfo.scheduleID
        )
        analytics.recordEvent(InAppDisplayEvent(), layoutContext: nil)
    }

    @MainActor
    func testDisplayContextNewIAA() async {
        let analytics = InAppMessageAnalytics(
            preparedScheduleInfo: preparedInfo,
            message: InAppMessage(
                name: "name",
                displayContent: .custom(.string("custom")),
                source: .legacyPush,
                isReportingEnabled: true,
                renderedLocale: AirshipJSON.string("rendered locale")
            ),
            displayImpressionRule: .once,
            eventRecorder: eventRecorder,
            historyStore: historyStore,
            displayHistory: MessageDisplayHistory()
        )


        analytics.recordEvent(TestInAppEvent(), layoutContext: nil)
        analytics.recordEvent(InAppDisplayEvent(), layoutContext: nil)
        analytics.recordEvent(TestInAppEvent(), layoutContext: nil)
        analytics.recordEvent(InAppDisplayEvent(), layoutContext: nil)
        analytics.recordEvent(TestInAppEvent(), layoutContext: nil)

        let firstDisplayContext = InAppEventContext.Display(
            triggerSessionID: preparedInfo.triggerSessionID,
            isFirstDisplay: true,
            isFirstDisplayTriggerSessionID: true
        )

        let secondDisplayContext = InAppEventContext.Display(
            triggerSessionID: preparedInfo.triggerSessionID,
            isFirstDisplay: false,
            isFirstDisplayTriggerSessionID: false
        )

        let expected = [
            // event before a display
            firstDisplayContext,
            // first display
            firstDisplayContext,
            // event after display
            firstDisplayContext,
            // second display
            secondDisplayContext,
            // event after display
            secondDisplayContext
        ]

        let displayContexts = self.eventRecorder.eventData.map { $0.context!.display }
        XCTAssertEqual(displayContexts, expected)
    }

    @MainActor
    func testDisplayContextPreviouslyDisplayIAX() async {
        let analytics = InAppMessageAnalytics(
            preparedScheduleInfo: preparedInfo,
            message: InAppMessage(
                name: "name",
                displayContent: .custom(.string("custom")),
                source: .legacyPush,
                isReportingEnabled: true,
                renderedLocale: AirshipJSON.string("rendered locale")
            ),
            displayImpressionRule: .once,
            eventRecorder: eventRecorder,
            historyStore: historyStore,
            displayHistory: MessageDisplayHistory(
                lastDisplay: .init(triggerSessionID: UUID().uuidString)
            )
        )

        analytics.recordEvent(TestInAppEvent(), layoutContext: nil)
        analytics.recordEvent(InAppDisplayEvent(), layoutContext: nil)
        analytics.recordEvent(TestInAppEvent(), layoutContext: nil)
        analytics.recordEvent(InAppDisplayEvent(), layoutContext: nil)
        analytics.recordEvent(TestInAppEvent(), layoutContext: nil)

        let firstDisplayContext = InAppEventContext.Display(
            triggerSessionID: preparedInfo.triggerSessionID,
            isFirstDisplay: false,
            isFirstDisplayTriggerSessionID: true
        )

        let secondDisplayContext = InAppEventContext.Display(
            triggerSessionID: preparedInfo.triggerSessionID,
            isFirstDisplay: false,
            isFirstDisplayTriggerSessionID: false
        )

        let expected = [
            // event before a display
            firstDisplayContext,
            // first display
            firstDisplayContext,
            // event after display
            firstDisplayContext,
            // second display
            secondDisplayContext,
            // event after display
            secondDisplayContext
        ]

        let displayContexts = self.eventRecorder.eventData.map { $0.context!.display }
        XCTAssertEqual(displayContexts, expected)
    }

    @MainActor
    func testDisplayContextSameTriggerSessionID() async {
        let analytics = InAppMessageAnalytics(
            preparedScheduleInfo: preparedInfo,
            message: InAppMessage(
                name: "name",
                displayContent: .custom(.string("custom")),
                source: .legacyPush,
                isReportingEnabled: true,
                renderedLocale: AirshipJSON.string("rendered locale")
            ),
            displayImpressionRule: .once,
            eventRecorder: eventRecorder,
            historyStore: historyStore,
            displayHistory: MessageDisplayHistory(
                lastDisplay: .init(triggerSessionID: preparedInfo.triggerSessionID)
            )
        )

        analytics.recordEvent(TestInAppEvent(), layoutContext: nil)
        analytics.recordEvent(InAppDisplayEvent(), layoutContext: nil)
        analytics.recordEvent(TestInAppEvent(), layoutContext: nil)
        analytics.recordEvent(InAppDisplayEvent(), layoutContext: nil)
        analytics.recordEvent(TestInAppEvent(), layoutContext: nil)

        let firstDisplayContext = InAppEventContext.Display(
            triggerSessionID: preparedInfo.triggerSessionID,
            isFirstDisplay: false,
            isFirstDisplayTriggerSessionID: false
        )

        let secondDisplayContext = InAppEventContext.Display(
            triggerSessionID: preparedInfo.triggerSessionID,
            isFirstDisplay: false,
            isFirstDisplayTriggerSessionID: false
        )

        let expected = [
            // event before a display
            firstDisplayContext,
            // first display
            firstDisplayContext,
            // event after display
            firstDisplayContext,
            // second display
            secondDisplayContext,
            // event after display
            secondDisplayContext
        ]

        let displayContexts = self.eventRecorder.eventData.map { $0.context!.display }
        XCTAssertEqual(displayContexts, expected)
    }
}

final class EventRecorder: InAppEventRecorderProtocol, @unchecked Sendable {

    var lastRecordedImpression: AirshipMeteredUsageEvent?

    var eventData: [InAppEventData] = []
    func recordEvent(inAppEventData: InAppEventData) {
        eventData.append(inAppEventData)
    }

    func recordImpressionEvent(_ event: AirshipMeteredUsageEvent) {
        lastRecordedImpression = event
    }
}


final class TestDisplayHistoryStore: MessageDisplayHistoryStoreProtocol, @unchecked Sendable {
    var stored: [String: MessageDisplayHistory] = [:]

    func set(_ history: MessageDisplayHistory, scheduleID: String) {
        stored[scheduleID] = history
    }
    
    func get(scheduleID: String) async -> MessageDisplayHistory {
        return stored[scheduleID] ?? MessageDisplayHistory()
    }
}

