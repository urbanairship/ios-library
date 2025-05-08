/* Copyright Airship and Contributors */

import Testing

@testable import AirshipAutomation
@testable import AirshipCore

@MainActor
struct InAppMessageAnalyticsTest {

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
        triggerSessionID: UUID().uuidString,
        priority: 0
    )

    @Test
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
        let expectedID = InAppEventMessageID.airship(
            identifier: self.preparedInfo.scheduleID,
            campaigns: self.preparedInfo.campaigns
        )
        #expect(data.messageID == expectedID)
        #expect(data.source == .airship)
    }

    @Test
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

        let expectedID = InAppEventMessageID.appDefined(
            identifier: self.preparedInfo.scheduleID
        )
        #expect(data.messageID == expectedID)
        #expect(data.source == .appDefined)
    }

    @Test
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
        let expectedID = InAppEventMessageID.legacy(
            identifier: self.preparedInfo.scheduleID
        )
        #expect(data.messageID == expectedID)
        #expect(data.source == .airship)
    }

    @Test
    func testData() async throws {
        let thomasLayoutContext  = ThomasLayoutContext(
            pager: ThomasLayoutContext.Pager(
                identifier: UUID().uuidString,
                pageIdentifier: UUID().uuidString,
                pageIndex: 1,
                completed: false,
                count: 2
            ),
            button: ThomasLayoutContext.Button(identifier: UUID().uuidString),
            form: ThomasLayoutContext.Form(
            identifier: UUID().uuidString,
            submitted: true,
            type: UUID().uuidString,
            responseType: UUID().uuidString
            )
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
        #expect(data.context == expectedContext)
        #expect(data.renderedLocale == AirshipJSON.string("rendered locale"))
        #expect(data.event.name == EventType.customEvent)
    }
    
    @Test
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

        
        let impression = eventRecorder.lastRecordedImpression!
        #expect(preparedInfo.scheduleID == impression.entityID)
        #expect(AirshipMeteredUsageType.inAppExperienceImpression == impression.usageType)
        #expect(preparedInfo.productID == impression.product)
        #expect(preparedInfo.reportingContext == impression.reportingContext)
        #expect(date.now == impression.timestamp)
        #expect(preparedInfo.contactID == impression.contactID)

        eventRecorder.lastRecordedImpression = nil
        analytics.recordEvent(InAppDisplayEvent(), layoutContext: nil)
        #expect(eventRecorder.lastRecordedImpression == nil)

        let displayHistory = await self.historyStore.get(
            scheduleID: preparedInfo.scheduleID
        )
        #expect(displayHistory.lastImpression?.date == date.now)
        #expect(displayHistory.lastImpression?.triggerSessionID == preparedInfo.triggerSessionID)
    }

    @Test
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

        let impression = eventRecorder.lastRecordedImpression!
        #expect(preparedInfo.scheduleID == impression.entityID)
        #expect(AirshipMeteredUsageType.inAppExperienceImpression == impression.usageType)
        #expect(preparedInfo.productID == impression.product)
        #expect(preparedInfo.reportingContext == impression.reportingContext)
        #expect(date.now == impression.timestamp)
        #expect(preparedInfo.contactID == impression.contactID)

        eventRecorder.lastRecordedImpression = nil
        analytics.recordEvent(InAppDisplayEvent(), layoutContext: nil)
        #expect(eventRecorder.lastRecordedImpression == nil)

        var displayHistory = await self.historyStore.get(
            scheduleID: preparedInfo.scheduleID
        )
        #expect(displayHistory.lastImpression?.date == date.now)
        #expect(displayHistory.lastImpression?.triggerSessionID == preparedInfo.triggerSessionID)


        date.offset += 9.9
        analytics.recordEvent(InAppDisplayEvent(), layoutContext: nil)
        #expect(eventRecorder.lastRecordedImpression == nil)

        date.offset += 0.1
        analytics.recordEvent(InAppDisplayEvent(), layoutContext: nil)
        assert(eventRecorder.lastRecordedImpression != nil)

        displayHistory = await self.historyStore.get(
            scheduleID: preparedInfo.scheduleID
        )
        #expect(displayHistory.lastImpression?.date == date.now)
        #expect(displayHistory.lastImpression?.triggerSessionID == preparedInfo.triggerSessionID)
    }

    @Test
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
        assert(self.eventRecorder.eventData.isEmpty)

        // impressions are still recorded
        assert(eventRecorder.lastRecordedImpression != nil)
    }


    @Test
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
        #expect(displayHistory.lastDisplay?.triggerSessionID == nil)


        displayHistory = await self.historyStore.get(
            scheduleID: preparedInfo.scheduleID
        )
        analytics.recordEvent(InAppDisplayEvent(), layoutContext: nil)
    }

    @Test
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
        #expect(displayContexts == expected)
    }

    @Test
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
        #expect(displayContexts == expected)
    }

    @Test
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
        #expect(displayContexts == expected)
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

