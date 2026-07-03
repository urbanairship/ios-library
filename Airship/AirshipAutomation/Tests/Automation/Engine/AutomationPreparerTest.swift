/* Copyright Airship and Contributors */

import Testing
@_spi(AirshipInternal) import AirshipBasement
import Foundation

@testable @_spi(AirshipInternal)
import AirshipAutomation
import AirshipCore

@MainActor
struct AutomationPreparerTest {

    private let actionPreparer: TestPreparerDelegate<AirshipJSON, AirshipJSON> = TestPreparerDelegate()
    private let messagePreparer: TestPreparerDelegate<InAppMessage, PreparedInAppMessageData> = TestPreparerDelegate()
    private let remoteDataAccess: TestRemoteDataAccess = TestRemoteDataAccess()
    private let deferredResolver: TestDeferredResolver = TestDeferredResolver()
    private let experiments: TestExperimentDataProvider = TestExperimentDataProvider()
    private let frequencyLimits: TestFrequencyLimitManager = TestFrequencyLimitManager()
    private let audienceChecker: TestAudienceChecker = TestAudienceChecker()
    private let preparer: AutomationPreparer!
    private let deviceInfoProvider = TestDeviceInfoProvider()
    private let audienceAdditionalResolver = TestAdditionalAudienceResolver()

    private let triggerContext = AirshipTriggerContext(type: "some type", goal: 10, event: .null)

    private let preparedMessageData: PreparedInAppMessageData!
    private let runtimeConfig: RuntimeConfig = .testConfig()
    init() async throws {
        self.preparedMessageData = PreparedInAppMessageData(
            message: InAppMessage(
                name: "some name",
                displayContent: .custom(.string("custom"))
            ),
            displayAdapter: TestDisplayAdapter(),
            displayCoordinator: TestDisplayCoordinator(),
            analytics: TestInAppMessageAnalytics(),
            actionRunner: TestInAppActionRunner()
        )

        self.preparer = AutomationPreparer(
            actionPreparer: actionPreparer,
            messagePreparer: messagePreparer,
            deferredResolver: deferredResolver,
            frequencyLimits: frequencyLimits,
            audienceChecker: audienceChecker,
            experiments: experiments,
            remoteDataAccess: remoteDataAccess,
            config: self.runtimeConfig,
            deviceInfoProviderFactory: { [provider = self.deviceInfoProvider] contactID in
                provider.stableContactInfo = StableContactInfo(contactID: contactID ?? UUID().uuidString)
                return provider
            },
            additionalAudienceResolver: audienceAdditionalResolver
        )
    
    }

    @Test
    func testRequiresUpdate() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            triggers: [],
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            )
        )

        self.remoteDataAccess.requiresUpdateBlock = { schedule in
            #expect(automationSchedule == schedule)
            return true
        }

        self.remoteDataAccess.waitFullRefreshBlock = { schedule in
            #expect(automationSchedule == schedule)
        }

        let prepareResult = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext,
            triggerSessionID: UUID().uuidString
        )
        
        #expect(prepareResult.isInvalidate)
    }

    @Test
    func testBestEfforRefreshNotCurrent() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            triggers: [],
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            )
        )

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { schedule in
            #expect(automationSchedule == schedule)
            return false
        }

        let prepareResult = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext,
            triggerSessionID: UUID().uuidString
        )

        #expect(prepareResult.isInvalidate)
    }

    @Test
    func testAudienceMismatchSkip() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            triggers: [],
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            ),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .skip
            ),
            compoundAudience: .init(
                selector: .atomic(.init(newUser: true)),
                missBehavior: .cancel)
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return nil
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }
        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { audience, created, _ in
            #expect(
                audience ==
                CompoundDeviceAudienceSelector.combine(
                    compoundSelector: automationSchedule.compoundAudience!.selector,
                    deviceSelector: automationSchedule.audience!.audienceSelector
                )
            )
            #expect(created == automationSchedule.created)
            return .miss
        }

        let prepareResult = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext,
            triggerSessionID: UUID().uuidString
        )

        /// Uses compound selector if available
        #expect(prepareResult.isCancelled)
    }
    
    @Test
    func testAudienceMismatchPenalize() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            triggers: [],
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            ),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            )
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return nil
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { audience, created, _ in
            #expect(audience == .atomic(automationSchedule.audience!.audienceSelector))
            #expect(created == automationSchedule.created)
            return .miss
        }

        let prepareResult = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext,
            triggerSessionID: UUID().uuidString
        )

        #expect(prepareResult.isPenalize)
    }
    
    @Test
    func testAudienceCheckFirst() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            triggers: [],
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            ),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .skip
            ),
            compoundAudience: .init(
                selector: .atomic(.init(newUser: true)),
                missBehavior: .cancel
            )
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return nil
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }
        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { audience, created, _ in
            #expect(
                audience ==
                CompoundDeviceAudienceSelector.combine(
                    compoundSelector: automationSchedule.compoundAudience!.selector,
                    deviceSelector: automationSchedule.audience!.audienceSelector
                )
            )
            #expect(created == automationSchedule.created)
            return .miss
        }

        let prepareResult = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext,
            triggerSessionID: UUID().uuidString
        )

        #expect(prepareResult.isCancelled)
    }
    
    @Test
    func testCompoundAudienceCheck() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            triggers: [],
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            ),
            audience: nil,
            compoundAudience: .init(
                selector: .atomic(.init(newUser: true)),
                missBehavior: .cancel)
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return nil
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }
        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { audience, created, provider in
            #expect(audience == automationSchedule.compoundAudience?.selector)
            #expect(created == automationSchedule.created)
            return .miss
        }

        let prepareResult = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext,
            triggerSessionID: UUID().uuidString
        )

        #expect(prepareResult.isCancelled)
    }


    @Test
    func testAudienceMismatchCancel() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            triggers: [],
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            ),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .cancel
            )
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return nil
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { audience, created, _ in
            #expect(audience == .atomic(automationSchedule.audience!.audienceSelector))
            #expect(created == automationSchedule.created)
            return .miss
        }

        let prepareResult = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext,
            triggerSessionID: UUID().uuidString
        )

        #expect(prepareResult.isCancelled)
    }

    @Test
    func testContactIDAudienceChecks() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            triggers: [],
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            ),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            )
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return "contact ID"
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }
        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, provider in
            let contactID = await provider.stableContactInfo.contactID
            #expect("contact ID" == contactID)
            return .miss
        }

        let _ = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext,
            triggerSessionID: UUID().uuidString
        )
    }

    @Test
    func testPrepareMessage() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            ),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            ),
            campaigns: "campaigns",
            frequencyConstraintIDs: ["constraint"]
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return "contact ID"
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _,  _, _ in
            return .match
        }

        let checker = TestFrequencyChecker()
        await self.frequencyLimits.setCheckerBlock { _ in
            return checker
        }

        let preparedData = self.preparedMessageData!

        self.messagePreparer.prepareBlock = { message, info in
            #expect(.inAppMessage(message) == automationSchedule.data)
            #expect(automationSchedule.identifier == info.scheduleID)
            #expect(automationSchedule.campaigns == info.campaigns)
            #expect("contact ID" == info.contactID)

            return preparedData
        }

        let triggerSessionID = UUID().uuidString

        let result = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext,
            triggerSessionID: triggerSessionID
        )

        guard case .prepared(let prepared) = result else {
            Issue.record()
            return
        }

        #expect(automationSchedule.identifier == prepared.info.scheduleID)
        #expect(automationSchedule.campaigns == prepared.info.campaigns)
        #expect(prepared.data == .inAppMessage(preparedData))
        #expect(triggerSessionID == prepared.info.triggerSessionID)

        #expect(prepared.frequencyChecker != nil)
    }
    
    @Test
    func testPrepareMessageCheckerError() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            ),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            ),
            campaigns: "campaigns",
            frequencyConstraintIDs: ["constraint"]
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return "contact ID"
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, _ in
            return .match
        }

        await self.frequencyLimits.setCheckerBlock { _ in
            throw AirshipErrors.error("Failed")
        }

        let triggerSessionID = UUID().uuidString

        let result = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext,
            triggerSessionID: triggerSessionID
        )

        #expect(result.isSkipped)
    }

    @Test
    func testAdditionalAudienceMiss() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            triggers: [],
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            ),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .skip
            )
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return nil
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }
        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, _ in
            return .match
        }

        await self.audienceAdditionalResolver.setResult(false)

        let preparedData = self.preparedMessageData!

        self.messagePreparer.prepareBlock = { message, info in
            #expect(!(info.additionalAudienceCheckResult))
            return preparedData
        }

        let prepareResult = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext,
            triggerSessionID: UUID().uuidString
        )

        guard case .prepared(let prepared) = prepareResult else {
            Issue.record()
            return
        }
        #expect(!(prepared.info.additionalAudienceCheckResult))
    }

    @Test
    func testPrepareInvalidMessage() async throws {
        let invalidBanner = InAppMessageDisplayContent.Banner(
            heading: nil,
            body: nil,
            media: nil,
            buttons: nil,
            buttonLayoutType: .stacked,
            template: .mediaLeft,
            backgroundColor: InAppMessageColor(hexColorString: ""),
            dismissButtonColor:  InAppMessageColor(hexColorString: ""),
            borderRadius: 5,
            duration: 100.0,
            placement: .top
        )

        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .banner(invalidBanner))
            ),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            ),
            campaigns: "campaigns",
            frequencyConstraintIDs: ["constraint"]
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return "contact ID"
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, _ in
            return .match
        }

        let checker = TestFrequencyChecker()
        await self.frequencyLimits.setCheckerBlock { _ in
            return checker
        }

        let preparedData = self.preparedMessageData!

        self.messagePreparer.prepareBlock = { message, info in
            #expect(.inAppMessage(message) == automationSchedule.data)
            #expect(automationSchedule.identifier == info.scheduleID)
            #expect(automationSchedule.campaigns == info.campaigns)
            #expect("contact ID" == info.contactID)

            return preparedData
        }

        let result = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext,
            triggerSessionID: UUID().uuidString
        )

        #expect(result.isSkipped)
    }

    @Test
    func testPrepareActions() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            data: .actions(
                AirshipJSON.string("actions payload")
            ),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            ),
            campaigns: "campaigns",
            frequencyConstraintIDs: ["constraint"]
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return "contact ID"
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, _ in
            return .match
        }

        let checker = TestFrequencyChecker()
        await self.frequencyLimits.setCheckerBlock { _ in
            return checker
        }


        self.actionPreparer.prepareBlock = { actions, info in
            #expect(.actions(actions) == automationSchedule.data)
            #expect(automationSchedule.identifier == info.scheduleID)
            #expect(automationSchedule.campaigns == info.campaigns)
            #expect("contact ID" == info.contactID)
            return actions
        }

        let result = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext,
            triggerSessionID: UUID().uuidString
        )

        guard case .prepared(let prepared) = result else {
            Issue.record()
            return
        }

        #expect(automationSchedule.identifier == prepared.info.scheduleID)
        #expect(automationSchedule.campaigns == prepared.info.campaigns)
        #expect(prepared.data == .actions(AirshipJSON.string("actions payload")))
        #expect(prepared.frequencyChecker != nil)
    }

    @Test
    func testPrepareDeferredActions() async throws {
        let actions = try! AirshipJSON.wrap(["some": "action"])
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            data: .deferred(
                DeferredAutomationData(
                    url: URL(string: "example://")!,
                    retryOnTimeOut: false,
                    type: .actions
                )
            ),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            ),
            campaigns: "campaigns",
            frequencyConstraintIDs: ["constraint"]
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return "contact ID"
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, _ in
            return .match
        }

        let checker = TestFrequencyChecker()
        await self.frequencyLimits.setCheckerBlock { _ in
            return checker
        }

        await self.deferredResolver.onData { request in
            let data = try! AirshipJSON.wrap([
                "audience_match": true,
                "actions": actions
            ]).toData()
            return .success(data)
        }
        
        self.actionPreparer.prepareBlock = { actionsPayload, info in
            #expect(actionsPayload == actions)
            #expect(automationSchedule.identifier == info.scheduleID)
            #expect(automationSchedule.campaigns == info.campaigns)
            #expect("contact ID" == info.contactID)
            return actions
        }

        let result = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext,
            triggerSessionID: UUID().uuidString
        )

        guard case .prepared(let prepared) = result else {
            Issue.record()
            return
        }

        #expect(automationSchedule.identifier == prepared.info.scheduleID)
        #expect(automationSchedule.campaigns == prepared.info.campaigns)
        #expect(prepared.data == .actions(actions))
        #expect(prepared.frequencyChecker != nil)
    }

    @Test
    func testPrepareDeferredMessage() async throws {

        let message = InAppMessage(
            name: "some name",
            displayContent: .custom(.string("custom")),
            source: .remoteData
        )

        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            data: .deferred(
                DeferredAutomationData(
                    url: URL(string: "example://")!,
                    retryOnTimeOut: false,
                    type: .inAppMessage
                )
            ),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            ),
            campaigns: "campaigns",
            frequencyConstraintIDs: ["constraint"]
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return self.deviceInfoProvider.stableContactInfo.contactID
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, _ in
            return .match
        }

        let checker = TestFrequencyChecker()
        await self.frequencyLimits.setCheckerBlock { _ in
            return checker
        }

        let expectedRequest = DeferredRequest(
            url: URL(string: "example://")!,
            channelID: self.deviceInfoProvider.channelID,
            contactID: self.deviceInfoProvider.stableContactInfo.contactID,
            triggerContext: triggerContext,
            locale: deviceInfoProvider.locale,
            notificationOptIn: deviceInfoProvider.isUserOptedInPushNotifications
        )

        await self.deferredResolver.onData { request in
            #expect(request == expectedRequest)
            let data = try! AirshipJSON.wrap([
                "audience_match": true,
                "message": message
            ]).toData()
            return .success(data)
        }

        let preparedData = self.preparedMessageData!
        let contactID = self.deviceInfoProvider.stableContactInfo.contactID
        self.messagePreparer.prepareBlock = { inAppMessage, info in
            #expect(inAppMessage == message)
            #expect(automationSchedule.identifier == info.scheduleID)
            #expect(automationSchedule.campaigns == info.campaigns)
            #expect(contactID == info.contactID)
            return preparedData
        }

        let result = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext,
            triggerSessionID: UUID().uuidString
        )

        guard case .prepared(let prepared) = result else {
            Issue.record()
            return
        }

        #expect(automationSchedule.identifier == prepared.info.scheduleID)
        #expect(automationSchedule.campaigns == prepared.info.campaigns)
        #expect(prepared.frequencyChecker != nil)
    }

    @Test
    func testPrepareDeferredAudienceMismatchResult() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            data: .deferred(
                DeferredAutomationData(
                    url: URL(string: "example://")!,
                    retryOnTimeOut: false,
                    type: .inAppMessage
                )
            ),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .skip
            )
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return "contact ID"
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, _ in
            return .match
        }

        await self.deferredResolver.onData { request in
            let data = try! AirshipJSON.wrap([
                "audience_match": false
            ]).toData()
            return .success(data)
        }

        let result = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext,
            triggerSessionID: UUID().uuidString
        )

        #expect(result.isSkipped)
    }

    @Test
    func testExperiements() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            ),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            ),
            campaigns: "campaigns",
            frequencyConstraintIDs: ["constraint"]
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return "contact ID"
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, _ in
            return .match
        }

        let checker = TestFrequencyChecker()
        await self.frequencyLimits.setCheckerBlock { _ in
            return checker
        }

        let preparedData = self.preparedMessageData!

        self.messagePreparer.prepareBlock = { message, info in
            #expect(.inAppMessage(message) == automationSchedule.data)
            #expect(automationSchedule.identifier == info.scheduleID)
            #expect(automationSchedule.campaigns == info.campaigns)
            #expect("contact ID" == info.contactID)

            return preparedData
        }

        let result = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext,
            triggerSessionID: UUID().uuidString
        )

        guard case .prepared(let prepared) = result else {
            Issue.record()
            return
        }

        #expect(automationSchedule.identifier == prepared.info.scheduleID)
        #expect(automationSchedule.campaigns == prepared.info.campaigns)
        #expect(prepared.data == .inAppMessage(preparedData))
        #expect(prepared.frequencyChecker != nil)
    }

    @Test
    func testExperiments() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            ),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            ),
            campaigns: "campaigns",
            messageType: "some message type"
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return "contact ID"
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, _ in
            return .match
        }

        let experimentResult = ExperimentResult(
            channelID: "some channel",
            contactID: "contact ID",
            isMatch: true,
            reportingMetadata: [AirshipJSON.string("reporting")]
        )

        self.experiments.onEvaluate = { info, provider in
            let contactID = await provider.stableContactInfo.contactID
            #expect(
                info ==
                MessageInfo(
                    messageType: automationSchedule.messageType!,
                    campaigns: automationSchedule.campaigns
                )
            )
            #expect(contactID == "contact ID")
            return experimentResult
        }
        
        let preparedData = self.preparedMessageData!

        self.messagePreparer.prepareBlock = { message, info in
            #expect(automationSchedule.identifier == info.scheduleID)
            #expect(experimentResult == info.experimentResult)
            return preparedData
        }

        let result = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext,
            triggerSessionID: UUID().uuidString
        )

        guard case .prepared(let prepared) = result else {
            Issue.record()
            return
        }
        #expect(experimentResult == prepared.info.experimentResult)
    }

    @Test
    func testExperimentsDefaultMessageType() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            ),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            ),
            campaigns: "campaigns"
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return "contact ID"
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, _ in
            return .match
        }

        let experimentResult = ExperimentResult(
            channelID: "some channel",
            contactID: "contact ID",
            isMatch: true,
            reportingMetadata: [AirshipJSON.string("reporting")]
        )

        self.experiments.onEvaluate = { info, provider in
            let contactID = await provider.stableContactInfo.contactID
            #expect(
                info ==
                MessageInfo(
                    messageType: "transactional",
                    campaigns: automationSchedule.campaigns
                )
            )
            #expect(contactID == "contact ID")
            return experimentResult
        }

        let preparedData = self.preparedMessageData!

        self.messagePreparer.prepareBlock = { message, info in
            #expect(automationSchedule.identifier == info.scheduleID)
            #expect(experimentResult == info.experimentResult)
            return preparedData
        }

        let result = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext,
            triggerSessionID: UUID().uuidString
        )

        guard case .prepared(let prepared) = result else {
            Issue.record()
            return
        }
        #expect(experimentResult == prepared.info.experimentResult)
    }

    @Test
    func testByPassExperiments() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            ),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            ),
            bypassHoldoutGroups: true,
            campaigns: "campaigns",
            messageType: "some message type"
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return "contact ID"
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, _ in
            return .match
        }

        self.experiments.onEvaluate = { info, provider in
            Issue.record()
            return nil
        }

        let preparedData = self.preparedMessageData!

        self.messagePreparer.prepareBlock = { message, info in
            #expect(info.experimentResult == nil)
            return preparedData
        }

        let result = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext,
            triggerSessionID: UUID().uuidString
        )

        guard case .prepared(let prepared) = result else {
            Issue.record()
            return
        }

        #expect(prepared.info.experimentResult == nil)
    }

    @Test
    func testByPassExperimentsActions() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            data: .actions(
                AirshipJSON.string("payload")
            ),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            ),
            bypassHoldoutGroups: false, // even if false
            campaigns: "campaigns",
            messageType: "some message type"
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return "contact ID"
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, _ in
            return .match
        }

        self.experiments.onEvaluate = { info, provider in
            Issue.record()
            return nil
        }

        self.actionPreparer.prepareBlock = { actions, info in
            #expect(info.experimentResult == nil)
            return actions
        }

        let result = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext,
            triggerSessionID: UUID().uuidString
        )

        guard case .prepared(let prepared) = result else {
            Issue.record()
            return
        }

        #expect(prepared.info.experimentResult == nil)
    }
}


final class TestPreparerDelegate<In: Sendable, Out: Sendable>: AutomationPreparerDelegate, @unchecked Sendable {
    typealias PrepareDataIn = In
    typealias PrepareDataOut = Out

    var cancelledCalled: Bool = false
    var cancelledBlock: (@Sendable (String) async -> Void)?

    func cancelled(scheduleID: String) async {
        cancelledCalled = true
        await cancelledBlock!(scheduleID)
    }

    var prepareCalled: Bool = false
    var prepareBlock: (@Sendable (In, PreparedScheduleInfo) async -> Out)?

    func prepare(data: In, preparedScheduleInfo: PreparedScheduleInfo) async throws -> DelegatePreparerResult<Out> {
        prepareCalled = true
        return .prepared(await prepareBlock!(data, preparedScheduleInfo))
    }
}




extension SchedulePrepareResult {
    var isInvalidate: Bool {
        switch (self) {
        case .invalidate: return true
        default: return false
        }
    }

    var isPrepared: Bool {
        switch (self) {
        case .prepared(_): return true
        default: return false
        }
    }

    var isCancelled: Bool {
        switch (self) {
        case .cancel: return true
        default: return false
        }
    }

    var isSkipped: Bool {
        switch (self) {
        case .skip: return true
        default: return false
        }
    }

    var isPenalize: Bool {
        switch (self) {
        case .penalize: return true
        default: return false
        }
    }
}


final class TestDeviceInfoProvider: AudienceDeviceInfoProvider, @unchecked Sendable {
    var sdkVersion: String = "1.0.0"


    var isAirshipReady: Bool = false

    var tags: Set<String> = Set()

    var isChannelCreated: Bool = true

    var channelID: String = UUID().uuidString

    var locale: Locale = Locale.current

    var appVersion: String?

    var permissions: [AirshipCore.AirshipPermission : AirshipCore.AirshipPermissionStatus] = [:]

    var isUserOptedInPushNotifications: Bool = false

    var analyticsEnabled: Bool = false

    var installDate: Date = Date()

    var stableContactInfo: StableContactInfo

    init(contactID: String = UUID().uuidString) {
        self.stableContactInfo = StableContactInfo(contactID: contactID)
    }

}
