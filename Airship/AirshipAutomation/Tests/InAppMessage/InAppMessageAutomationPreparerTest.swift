/* Copyright Airship and Contributors */

import Testing
@_spi(AirshipInternal) import AirshipBasement
import Foundation
@_spi(AirshipInternal) @testable @_spi(AirshipInternal) import AirshipAutomation
import AirshipCore

@MainActor
struct InAppMessageAutomationPreparerTest {

    private let displayCoordinatorManager: TestDisplayCoordinatorManager = TestDisplayCoordinatorManager()
    private let displayAdapterFactory: TestDisplayAdapterFactory = TestDisplayAdapterFactory()
    private let assetManager: TestAssetManager = TestAssetManager()
    private let analyticsFactory: TestAnalyticsFactory = TestAnalyticsFactory()
    private let analytics: TestInAppMessageAnalytics = TestInAppMessageAnalytics()
    private let actionRunnerFactory: TestInAppActionRunnerFactory = TestInAppActionRunnerFactory()
    private let aiManager: TestAIManager = TestAIManager()

    private let preparer: InAppMessageAutomationPreparer
    private let message: InAppMessage = InAppMessage(
        name: "",
        displayContent: .banner(.init(media: .init(url: "some-url", type: .image)))
    )

    private let preparedScheduleInfo: PreparedScheduleInfo = PreparedScheduleInfo(
        scheduleID: UUID().uuidString,
        campaigns: "campigns",
        contactID: UUID().uuidString,
        experimentResult: nil,
        triggerSessionID: UUID().uuidString,
        priority: 0
    )

    init() {
        analyticsFactory.setOnMake { [analytics] _, _ in
            return analytics
        }
        self.preparer = InAppMessageAutomationPreparer(
            assetManager: assetManager,
            displayCoordinatorManager: displayCoordinatorManager,
            displayAdapterFactory: displayAdapterFactory,
            analyticsFactory: analyticsFactory,
            actionRunnerFactory: actionRunnerFactory,
            aiManager: aiManager
        )

        actionRunnerFactory.onMake = { _, _ in return TestInAppActionRunner() }
    }

    @Test
    func testPrepare() async throws {
        let runner = TestInAppActionRunner()
        actionRunnerFactory.onMake = { _, _ in return runner }

        let cachedAssets = TestCachedAssets()
        await self.assetManager.setOnCache { [preparedScheduleInfo] identifier, assets in
            #expect(identifier == preparedScheduleInfo.scheduleID)
            #expect(["some-url"] == assets)
            return cachedAssets
        }

        let displayCoordinator = TestDisplayCoordinator()
        self.displayCoordinatorManager.onCoordinator = { [message] incoming in
            #expect(message == incoming)
            return displayCoordinator
        }

        let displayAdapter = TestDisplayAdapter()
        self.displayAdapterFactory.onMake = { [message] args in
            #expect(message == args.message)
            let incomingAssets = args.assets as? TestCachedAssets
            #expect(incomingAssets === cachedAssets)
            return displayAdapter
        }

        guard case .prepared(let results) = try await self.preparer.prepare(data: message, preparedScheduleInfo: preparedScheduleInfo) else {
            Issue.record("Expected .prepared result")
            return
        }

        #expect(self.message == results.message)
        #expect(displayCoordinator === results.displayCoordinator)
        #expect(displayAdapter === (results.displayAdapter as? TestDisplayAdapter))
        #expect(runner === (results.actionRunner as? TestInAppActionRunner))
    }

    @Test
    func testPrepareFailedAssets() async throws {
        let displayCoordinator = TestDisplayCoordinator()
        let adapter = TestDisplayAdapter()
        
        self.displayCoordinatorManager.onCoordinator = { _ in
            return displayCoordinator
        }

        self.displayAdapterFactory.onMake = { _ in
            return adapter
        }

        await self.assetManager.setOnCache { identifier, assets in
            throw AirshipErrors.error("failed")
        }

        do {
            _ = try await self.preparer.prepare(data: message, preparedScheduleInfo: preparedScheduleInfo)
            Issue.record("should throw")
        } catch {}
    }

    @Test
    func testPrepareFailedAdapter() async throws {
        let displayCoordinator = TestDisplayCoordinator()
        self.displayCoordinatorManager.onCoordinator = { _ in
            return displayCoordinator
        }

        self.displayAdapterFactory.onMake = { _ in
            throw AirshipErrors.error("failed")
        }

        await self.assetManager.setOnCache { _, _ in
            return TestCachedAssets()
        }

        do {
            _ = try await self.preparer.prepare(data: message, preparedScheduleInfo: preparedScheduleInfo)
            Issue.record("should throw")
        } catch {}
    }

    @Test
    func testPrepareIntermediateLayoutResolveFails_appDefined_cancels() async throws {
        // A broken layout JSON (not a valid AirshipLayoutWrapper) on an app-defined
        // schedule should return .cancel — the payload won't be updated by remote data.
        let badMessage = InAppMessage(
            name: "bad layout",
            displayContent: .airshipLayoutIntermediate(AirshipLayoutIntermediate(layoutJSON: .string("not a layout")))
        )
        let result = try await self.preparer.prepare(data: badMessage, preparedScheduleInfo: preparedScheduleInfo)
        guard case .cancel = result else {
            Issue.record("Expected .cancel, got \(result)")
            return
        }
    }

    @Test
    func testPrepareIntermediateLayoutResolveFails_remoteData_skips() async throws {
        // A broken layout JSON on a remote-data schedule should return .skip so the
        // schedule goes back to idle and retries after the server pushes a fix.
        let badMessage = InAppMessage(
            name: "bad layout",
            displayContent: .airshipLayoutIntermediate(AirshipLayoutIntermediate(layoutJSON: .string("not a layout"))),
            source: .remoteData
        )
        let result = try await self.preparer.prepare(data: badMessage, preparedScheduleInfo: preparedScheduleInfo)
        guard case .skip = result else {
            Issue.record("Expected .skip, got \(result)")
            return
        }
    }

    @Test
    func testCancelled() async throws {
        let scheduleID = UUID().uuidString
        await self.preparer.cancelled(scheduleID: scheduleID)

        let cleared = await self.assetManager.cleared
        #expect(cleared == [scheduleID])
    }

    @Test
    func testAppSuppressionMatch() async throws {
        let coordinator = TestDisplayCoordinator()
        let adapter = TestDisplayAdapter()
        await self.assetManager.setOnCache { _, _ in TestCachedAssets() }
        self.displayCoordinatorManager.onCoordinator = { _ in coordinator }
        self.displayAdapterFactory.onMake = { _ in adapter }

        preparer.onCheckSuppression = { _, _ in .show }

        guard case .prepared = try await self.preparer.prepare(data: message, preparedScheduleInfo: preparedScheduleInfo) else {
            Issue.record("Expected .prepared")
            return
        }
    }

    @Test
    func testAppSuppressionMissSkip() async throws {
        // onCache intentionally not set — if assets are prepared the force-unwrap crashes
        preparer.onCheckSuppression = { _, _ in .suppress(.skip) }

        let result = try await self.preparer.prepare(data: message, preparedScheduleInfo: preparedScheduleInfo)
        guard case .skip = result else {
            Issue.record("Expected .skip, got \(result)")
            return
        }
    }

    @Test
    func testAppSuppressionMissCancel() async throws {
        preparer.onCheckSuppression = { _, _ in .suppress(.cancel) }

        let result = try await self.preparer.prepare(data: message, preparedScheduleInfo: preparedScheduleInfo)
        guard case .cancel = result else {
            Issue.record("Expected .cancel, got \(result)")
            return
        }
    }

    @Test
    func testAppSuppressionMissPenalize() async throws {
        preparer.onCheckSuppression = { _, _ in .suppress(.penalize) }

        let result = try await self.preparer.prepare(data: message, preparedScheduleInfo: preparedScheduleInfo)
        guard case .penalize = result else {
            Issue.record("Expected .penalize, got \(result)")
            return
        }
    }

    @Test
    func testAppSuppressionThrows() async throws {
        preparer.onCheckSuppression = { _, _ in throw AirshipErrors.error("LLM unavailable") }

        do {
            _ = try await self.preparer.prepare(data: message, preparedScheduleInfo: preparedScheduleInfo)
            Issue.record("Expected throw")
        } catch {}
    }

    @Test
    func testAppSuppressionReceivesMessageAndScheduleID() async throws {
        let coordinator = TestDisplayCoordinator()
        let adapter = TestDisplayAdapter()
        await self.assetManager.setOnCache { _, _ in TestCachedAssets() }
        self.displayCoordinatorManager.onCoordinator = { _ in coordinator }
        self.displayAdapterFactory.onMake = { _ in adapter }

        let receivedMessage = AirshipAtomicValue<InAppMessage?>(nil)
        let receivedScheduleID = AirshipAtomicValue<String?>(nil)

        self.preparer.onCheckSuppression = { message, scheduleID in
            receivedMessage.set(message)
            receivedScheduleID.set(scheduleID)
            return .show
        }

        _ = try await self.preparer.prepare(data: message, preparedScheduleInfo: preparedScheduleInfo)

        #expect(receivedMessage.value == message)
        #expect(receivedScheduleID.value == preparedScheduleInfo.scheduleID)
    }

    @Test
    func testAppSuppressionNilSkipsHook() async throws {
        let coordinator = TestDisplayCoordinator()
        let adapter = TestDisplayAdapter()
        await self.assetManager.setOnCache { _, _ in TestCachedAssets() }
        self.displayCoordinatorManager.onCoordinator = { _ in coordinator }
        self.displayAdapterFactory.onMake = { _ in adapter }

        // no hook set — should prepare normally
        guard case .prepared = try await self.preparer.prepare(data: message, preparedScheduleInfo: preparedScheduleInfo) else {
            Issue.record("Expected .prepared")
            return
        }
    }

    // MARK: - AI suppression

    /// A message with extras (context), no longer carrying the condition — that now comes
    /// from the schedule's `ai_suppression`.
    private func suppressionMessage() -> InAppMessage {
        InAppMessage(
            name: "promo",
            displayContent: .banner(.init(media: .init(url: "some-url", type: .image))),
            extras: .object(["promo_type": .string("flash_sale")])
        )
    }

    /// `preparedScheduleInfo` carrying an `ai_suppression` config.
    private func suppressionInfo(
        condition: String = "only show to hikers",
        missBehavior: AutomationAudience.MissBehavior? = nil,
        subjectHints: [String: String]? = nil
    ) -> PreparedScheduleInfo {
        var info = preparedScheduleInfo
        info.priority = 7
        info.aiSuppression = AutomationAISuppression(
            condition: condition,
            subjectHints: subjectHints,
            missBehavior: missBehavior
        )
        return info
    }

    private func setupDisplayStubs() async {
        await self.assetManager.setOnCache { _, _ in TestCachedAssets() }
        self.displayCoordinatorManager.onCoordinator = { _ in TestDisplayCoordinator() }
        self.displayAdapterFactory.onMake = { _ in TestDisplayAdapter() }
    }

    @Test
    func testAISuppressionSkipsByDefaultWhenNotAllowed() async throws {
        // onCache intentionally not set — the message must be skipped before assets are prepared.
        aiManager.onEvaluate = { _ in
            AirshipAI.Result<InAppMessageAISuppressionEvaluation.Output>.completed(
                .init(allow: false, reason: "not relevant")
            )
        }

        let result = try await self.preparer.prepare(data: suppressionMessage(), preparedScheduleInfo: suppressionInfo())
        guard case .skip = result else {
            Issue.record("Expected .skip, got \(result)")
            return
        }
    }

    @Test(arguments: [
        (AutomationAudience.MissBehavior.cancel, "cancel"),
        (AutomationAudience.MissBehavior.skip, "skip"),
        (AutomationAudience.MissBehavior.penalize, "penalize"),
    ])
    func testAISuppressionAppliesMissBehavior(missBehavior: AutomationAudience.MissBehavior, label: String) async throws {
        aiManager.onEvaluate = { _ in
            AirshipAI.Result<InAppMessageAISuppressionEvaluation.Output>.completed(.init(allow: false, reason: ""))
        }

        let result = try await self.preparer.prepare(
            data: suppressionMessage(),
            preparedScheduleInfo: suppressionInfo(missBehavior: missBehavior)
        )
        switch (missBehavior, result) {
        case (.cancel, .cancel), (.skip, .skip), (.penalize, .penalize): break
        default: Issue.record("Expected .\(label), got \(result)")
        }
    }

    @Test
    func testAISuppressionAllowsWhenAllowed() async throws {
        await setupDisplayStubs()
        aiManager.onEvaluate = { _ in
            AirshipAI.Result<InAppMessageAISuppressionEvaluation.Output>.completed(
                .init(allow: true, reason: "relevant")
            )
        }

        guard case .prepared = try await self.preparer.prepare(data: suppressionMessage(), preparedScheduleInfo: suppressionInfo()) else {
            Issue.record("Expected .prepared")
            return
        }
    }

    @Test
    func testAISuppressionFailsOpenWhenSkipped() async throws {
        await setupDisplayStubs()
        aiManager.onEvaluate = { _ in
            AirshipAI.Result<InAppMessageAISuppressionEvaluation.Output>.skipped(reason: "model unavailable")
        }

        guard case .prepared = try await self.preparer.prepare(data: suppressionMessage(), preparedScheduleInfo: suppressionInfo()) else {
            Issue.record("Expected .prepared on skipped evaluation (fail open)")
            return
        }
    }

    @Test
    func testAISuppressionFailsOpenWhenFailed() async throws {
        await setupDisplayStubs()
        aiManager.onEvaluate = { _ in
            AirshipAI.Result<InAppMessageAISuppressionEvaluation.Output>.failed(AirshipErrors.error("boom"))
        }

        guard case .prepared = try await self.preparer.prepare(data: suppressionMessage(), preparedScheduleInfo: suppressionInfo()) else {
            Issue.record("Expected .prepared on failed evaluation (fail open)")
            return
        }
    }

    @Test
    func testAISuppressionNotRunWithoutConfig() async throws {
        await setupDisplayStubs()

        let evaluated = AirshipAtomicValue<Bool>(false)
        aiManager.onEvaluate = { _ in
            evaluated.set(true)
            return AirshipAI.Result<InAppMessageAISuppressionEvaluation.Output>.completed(.init(allow: false, reason: ""))
        }

        // No aiSuppression on the prepared info — suppression must not run, and the message prepares.
        guard case .prepared = try await self.preparer.prepare(data: message, preparedScheduleInfo: preparedScheduleInfo) else {
            Issue.record("Expected .prepared")
            return
        }
        #expect(evaluated.value == false)
    }

    @Test
    func testAISuppressionPassesSubjectDetails() async throws {
        await setupDisplayStubs()

        let received = AirshipAtomicValue<InAppMessageAISuppressionEvaluation?>(nil)
        aiManager.onEvaluate = { evaluation in
            received.set(evaluation as? InAppMessageAISuppressionEvaluation)
            return AirshipAI.Result<InAppMessageAISuppressionEvaluation.Output>.completed(.init(allow: true, reason: ""))
        }

        _ = try await self.preparer.prepare(
            data: suppressionMessage(),
            preparedScheduleInfo: suppressionInfo(subjectHints: ["tier": "gold"])
        )

        let evaluation = try #require(received.value)
        #expect(evaluation.subject.name == "promo")
        #expect(evaluation.subject.extras?.object?["promo_type"]?.string == "flash_sale")
        #expect(evaluation.subject.priority == 7)
        #expect(evaluation.subject.hints == ["tier": "gold"])
        // The condition governs via instructions() — not repeated as context in the prompt.
        #expect(evaluation.instructions().contains("only show to hikers"))
        #expect(!evaluation.prompt(context: .empty).contains("only show to hikers"))
    }

}

fileprivate final class TestDisplayCoordinatorManager: DisplayCoordinatorManagerProtocol, @unchecked Sendable {
    var displayInterval: TimeInterval = 0.0
    var onCoordinator: ((InAppMessage) -> DisplayCoordinator)?
    func displayCoordinator(message: InAppMessage) -> DisplayCoordinator {
        self.onCoordinator!(message)
    }
}

fileprivate final class TestDisplayAdapterFactory: DisplayAdapterFactoryProtocol, @unchecked Sendable {
    var onMake: ((DisplayAdapterArgs) throws -> DisplayAdapter)?

    func setAdapterFactoryBlock(forType: CustomDisplayAdapterType, factoryBlock: @escaping @Sendable (DisplayAdapterArgs) -> (any CustomDisplayAdapter)?) {

    }
    
    func makeAdapter(args: DisplayAdapterArgs) throws -> any DisplayAdapter {
        return try self.onMake!(args)
    }
}



final class TestInAppActionRunnerFactory: InAppActionRunnerFactoryProtocol, @unchecked Sendable {
    var onMake: ((InAppMessage, InAppMessageAnalyticsProtocol) -> InternalInAppActionRunner)?


    func makeRunner(message: InAppMessage, analytics: any InAppMessageAnalyticsProtocol) -> any InternalInAppActionRunner {
        return self.onMake!(message, analytics)
    }
}

