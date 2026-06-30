/* Copyright Airship and Contributors */

import Testing

@testable
import AirshipCore
@_spi(AirshipInternal) import AirshipBasement
import Foundation

@MainActor
@Suite struct ExperimentManagerTest {

    private let deviceInfo: TestAudienceDeviceInfoProvider = TestAudienceDeviceInfoProvider()
    private let remoteData: TestRemoteData = TestRemoteData()
    private let subject: ExperimentManager
    private let audienceChecker: TestAudienceChecker = TestAudienceChecker()

    private let testDate: UATestDate = UATestDate(offset: 0, dateOverride: Date())

    init() async throws {
        self.deviceInfo.channelID = "channel-id"
        self.deviceInfo.stableContactInfo = StableContactInfo(contactID: "some-contact-id")

        self.subject = ExperimentManager(
            dataStore: PreferenceDataStore(appKey: UUID().uuidString),
            remoteData: remoteData,
            audienceChecker: audienceChecker,
            date: testDate
        )
    }

    @Test
    func testExperimentManagerOmitsInvalidExperiments() async throws {
        let experiment = Experiment.generate(id: "valid")
        self.remoteData.payloads = [createPayload([experiment.toString, "{ \"not valid\": true }"])]

        self.audienceChecker.onEvaluate = { audience, _, _ in
            .init(isMatch: true)
        }

        let result = try await subject.evaluateExperiments(
            info: MessageInfo.empty,
            deviceInfoProvider: self.deviceInfo
        )!

        #expect(
            [
                experiment.reportingMetadata
            ] ==
            result.reportingMetadata
        )
    }

    @Test
    func testExperimentManagerParseMultipleExperiments() async throws {
        let experiment1 = Experiment.generate(id: "id1")
        let experiment2 = Experiment.generate(id: "id2")

        self.remoteData.payloads = [
            createPayload([experiment1.toString]),
            createPayload([experiment2.toString])
        ]

        self.audienceChecker.onEvaluate = { _, _, _ in
            .init(isMatch: false)
        }

        let result = try await subject.evaluateExperiments(
            info: MessageInfo.empty,
            deviceInfoProvider: self.deviceInfo
        )!

        #expect(
            [
                experiment1.reportingMetadata,
                experiment2.reportingMetadata
            ] ==
            result.reportingMetadata
        )
    }

    @Test
    func testExperimentManagerHandleNoExperimentsPayload() async throws {
        self.remoteData.payloads = [createPayload(["{}"])]

        let result = try await subject.evaluateExperiments(
            info: MessageInfo.empty,
            deviceInfoProvider: self.deviceInfo
        )
        #expect(result == nil)
    }

    @Test
    func testExperimentManagerHandleInvalidPayload() async throws {
        let experiment = "{\"invalid\": \"experiment\"}"
        self.remoteData.payloads = [createPayload([experiment])]

        let result = try await subject.evaluateExperiments(
            info: MessageInfo.empty,
            deviceInfoProvider: self.deviceInfo
        )
        #expect(result == nil)
    }

    @Test
    func testResultNoExperiments() async throws {
        self.remoteData.payloads = [createPayload([])]

        let result = try await subject.evaluateExperiments(
            info: MessageInfo.empty,
            deviceInfoProvider: self.deviceInfo
        )

        #expect(result == nil)
    }

    @Test
    func testResultNoMatch() async throws {
        let experiment = Experiment.generate(id: "fake-id", reportingMetadata: AirshipJSON.string("reporting data!"))
        self.remoteData.payloads = [createPayload([experiment.toString])]

        self.audienceChecker.onEvaluate = { _, _, _ in
            .init(isMatch: false)
        }

        let result = try await subject.evaluateExperiments(
            info: MessageInfo.empty,
            deviceInfoProvider: self.deviceInfo
        )!

        #expect(!(result.isMatch))
        #expect(self.deviceInfo.stableContactInfo.contactID == result.contactID)
        #expect(self.deviceInfo.channelID == result.channelID)

        #expect(
            [
                experiment.reportingMetadata
            ] ==
            result.reportingMetadata
        )
    }

    @Test
    func testResultMatch() async throws {
        let audienceSelector1 = DeviceAudienceSelector(newUser: true)
        let experiment1 = Experiment.generate(
            id: "id1",
            reportingMetadata: AirshipJSON.string("reporting data 1"),
            audienceSelector: audienceSelector1
        )

        let audienceSelector2 = DeviceAudienceSelector(newUser: false)
        let experiment2 = Experiment.generate(
            id: "id2",
            reportingMetadata: AirshipJSON.string("reporting data 2"),
            audienceSelector: audienceSelector2
        )

        self.deviceInfo.stableContactInfo = StableContactInfo(contactID: "active-contact-id")

        self.remoteData.payloads = [createPayload([
            experiment1.toString,
            experiment2.toString
        ])]

        self.audienceChecker.onEvaluate = { audience, _, _ in
            .init(isMatch: audience == .atomic(audienceSelector2))
        }

        let result = try await subject.evaluateExperiments(
            info: MessageInfo.empty,
            deviceInfoProvider: self.deviceInfo
        )!

        #expect(result.isMatch)
        #expect("active-contact-id" == result.contactID)
        #expect("channel-id" == result.channelID)

        #expect(
            [
                experiment1.reportingMetadata,
                experiment2.reportingMetadata
            ] ==
            result.reportingMetadata
        )
    }

    @Test
    func testResultMatchExcludesInactive() async throws {
        let audienceSelector1 = DeviceAudienceSelector(newUser: true)
        let experiment1 = Experiment.generate(
            id: "id1",
            reportingMetadata: AirshipJSON.string("reporting data 1"),
            audienceSelector: audienceSelector1,
            timeCriteria: AirshipTimeCriteria(
                start: self.testDate.now + 0.01,
                end: self.testDate.now + 0.02
            )
        )

        let audienceSelector2 = DeviceAudienceSelector(newUser: false)
        let experiment2 = Experiment.generate(
            id: "id2",
            reportingMetadata: AirshipJSON.string("reporting data 2"),
            audienceSelector: audienceSelector2,
            timeCriteria: AirshipTimeCriteria(
                start: self.testDate.now,
                end: self.testDate.now + 0.01
            )
        )

        self.deviceInfo.stableContactInfo = StableContactInfo(contactID: "active-contact-id")

        self.remoteData.payloads = [createPayload([
            experiment1.toString,
            experiment2.toString
        ])]

        self.audienceChecker.onEvaluate = { audience, _, _ in
            .init(isMatch: audience == .atomic(audienceSelector2))
        }

        let result = try await subject.evaluateExperiments(
            info: MessageInfo.empty,
            deviceInfoProvider: self.deviceInfo
        )!

        #expect(result.isMatch)
        #expect("active-contact-id" == result.contactID)
        #expect("channel-id" == result.channelID)

        #expect(
            [
                experiment2.reportingMetadata
            ] ==
            result.reportingMetadata
        )
    }

    @Test
    func testResultMatchExclusions() async throws {
        let messageTypePredicate = JSONPredicate(
            jsonMatcher: JSONMatcher(valueMatcher: .matcherWhereStringEquals("transactional"))
        )

        let campaignsPredicate = JSONPredicate(
            jsonMatcher: JSONMatcher(
                valueMatcher: JSONValueMatcher.matcherWithArrayContainsPredicate(
                    JSONPredicate(
                        jsonMatcher: JSONMatcher(valueMatcher: .matcherWhereStringEquals("transactional campaign"))
                    )
                )!,
                scope: ["categories"]
            )
        )

        let experiment = Experiment.generate(
            id: "id1",
            reportingMetadata: AirshipJSON.string("reporting data 1"),
            exclusions: [
                MessageCriteria(
                    messageTypePredicate: messageTypePredicate,
                    campaignsPredicate: campaignsPredicate
                )
            ]
        )

        self.remoteData.payloads = [createPayload([experiment.toString])]


        self.audienceChecker.onEvaluate = { _, _, _ in
            return .match
        }

        let result = try await subject.evaluateExperiments(
            info: MessageInfo(
                messageType: "commercial",
                campaigns: try! AirshipJSON.wrap(["categories": ["foo", "bar"]])
            ),
            deviceInfoProvider: self.deviceInfo
        )!

        #expect(result.isMatch)
        #expect([experiment.reportingMetadata] == result.reportingMetadata)

        var emptyResult = try await subject.evaluateExperiments(
            info: MessageInfo(messageType: "transactional"),
            deviceInfoProvider: self.deviceInfo
        )

        #expect(emptyResult == nil)

        emptyResult = try await subject.evaluateExperiments(
            info: MessageInfo(
                messageType: "commercial",
                campaigns: try! AirshipJSON.wrap(["categories": ["foo", "bar", "transactional campaign"]])
            ),
            deviceInfoProvider: self.deviceInfo
        )

        #expect(emptyResult == nil)
    }
    
    private func createPayload(_ json: [String], type: String = "experiments") -> RemoteDataPayload {
        let wrapped = "{\"\(type)\": [\(json.joined(separator: ","))]}"
        let data =
            try! JSONSerialization.jsonObject(
                with: wrapped.data(using: .utf8)!,
                options: []
            ) as! [AnyHashable: Any]

        return RemoteDataPayload(
            type: type,
            timestamp: Date(),
            data: try! AirshipJSON.wrap(data),
            remoteDataInfo: nil
        )
    }
}

private extension MessageInfo {
    static nonisolated(unsafe) let empty = MessageInfo(messageType: "", campaigns: nil)
}

fileprivate extension Experiment {
    var toString: String {
        var definition: [String: AirshipJSON] = [
            "experiment_type": .string(type.rawValue),
            "type": .string(resolutionType.rawValue),
            "reporting_metadata": reportingMetadata,
        ]
        if let audienceSelector {
            definition["audience_selector"] = try! AirshipJSON.wrap(audienceSelector)
        }
        if let compoundAudience {
            definition["compound_audience"] = try! AirshipJSON.wrap(compoundAudience)
        }
        if let exclusions {
            definition["message_exclusions"] = try! AirshipJSON.wrap(exclusions)
        }
        if let timeCriteria {
            definition["time_criteria"] = try! AirshipJSON.wrap(timeCriteria)
        }

        let root: [String: AirshipJSON] = [
            "experiment_id": .string(id),
            "created": .string(AirshipDateFormatter.string(fromDate: created, format: .iso8601)),
            "last_updated": .string(AirshipDateFormatter.string(fromDate: lastUpdated, format: .iso8601)),
            "experiment_definition": .object(definition)
        ]

        return try! AirshipJSON.object(root).toString()
    }

    static func generate(
        id: String,
        created: Date = Date(),
        reportingMetadata: AirshipJSON = AirshipJSON.string("reporting!"),
        audienceSelector: DeviceAudienceSelector = DeviceAudienceSelector(),
        exclusions: [MessageCriteria]? = nil,
        timeCriteria: AirshipTimeCriteria? = nil
    ) -> Experiment {

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"

        let dateString = formatter.string(from: created)
        let normalized = formatter.date(from: dateString)!
        
        return Experiment(
            id: id,
            lastUpdated: normalized,
            created: normalized,
            reportingMetadata: reportingMetadata,
            audienceSelector: audienceSelector,
            exclusions: exclusions,
            timeCriteria: timeCriteria
        )
    }
}
