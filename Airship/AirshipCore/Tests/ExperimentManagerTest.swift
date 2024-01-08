/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class ExperimentManagerTest: XCTestCase {

    private var deviceInfo: TestAudienceDeviceInfoProvider = TestAudienceDeviceInfoProvider()
    private let remoteData: TestRemoteData = TestRemoteData()
    private var subject: ExperimentManager!
    private let audienceChecker: TestAudienceChecker = TestAudienceChecker()

    private let testDate: UATestDate = UATestDate(offset: 0, dateOverride: Date())

    override func setUpWithError() throws {
        self.deviceInfo.channelID = "channel-id"
        self.deviceInfo.stableContactID = "some-contact-id"

        self.subject = ExperimentManager(
            dataStore: PreferenceDataStore(appKey: UUID().uuidString),
            remoteData: remoteData,
            audienceChecker: audienceChecker,
            date: testDate
        )
    }

    func testExperimentManagerOmitsInvalidExperiments() async throws {
        let experiment = Experiment.generate(id: "valid")
        self.remoteData.payloads = [createPayload([experiment.toString, "{ \"not valid\": true }"])]

        let result = try await subject.evaluateExperiments(
            info: MessageInfo.empty,
            deviceInfoProvider: self.deviceInfo
        )!

        XCTAssertEqual(
            [
                experiment.reportingMetadata
            ],
            result.evaluatedExperimentsReportingData
        )
    }

    func testExperimentManagerParseMultipleExperiments() async throws {
        let experiment1 = Experiment.generate(id: "id1")
        let experiment2 = Experiment.generate(id: "id2")

        self.remoteData.payloads = [
            createPayload([experiment1.toString]),
            createPayload([experiment2.toString])
        ]


        let result = try await subject.evaluateExperiments(
            info: MessageInfo.empty,
            deviceInfoProvider: self.deviceInfo
        )!

        XCTAssertEqual(
            [
                experiment1.reportingMetadata,
                experiment2.reportingMetadata
            ],
            result.evaluatedExperimentsReportingData
        )
    }

    func testExperimentManagerHandleNoExperimentsPayload() async throws {
        self.remoteData.payloads = [createPayload(["{}"])]

        let result = try await subject.evaluateExperiments(
            info: MessageInfo.empty,
            deviceInfoProvider: self.deviceInfo
        )
        XCTAssertNil(result)
    }

    func testExperimentManagerHandleInvalidPayload() async throws {
        let experiment = "{\"invalid\": \"experiment\"}"
        self.remoteData.payloads = [createPayload([experiment])]

        let result = try await subject.evaluateExperiments(
            info: MessageInfo.empty,
            deviceInfoProvider: self.deviceInfo
        )
        XCTAssertNil(result)
    }

    func testResultNoExperiments() async throws {
        self.remoteData.payloads = [createPayload([])]

        let result = try await subject.evaluateExperiments(
            info: MessageInfo.empty,
            deviceInfoProvider: self.deviceInfo
        )

        XCTAssertNil(result)
    }

    func testResultNoMatch() async throws {
        let experiment = Experiment.generate(id: "fake-id", reportingMetadata: AirshipJSON.string("reporting data!"))
        self.remoteData.payloads = [createPayload([experiment.toString])]

        let result = try await subject.evaluateExperiments(
            info: MessageInfo.empty,
            deviceInfoProvider: self.deviceInfo
        )!

        XCTAssertFalse(result.isMatch)
        XCTAssertEqual(self.deviceInfo.stableContactID, result.contactID)
        XCTAssertEqual(self.deviceInfo.channelID, result.channelID)

        XCTAssertEqual(
            [
                experiment.reportingMetadata
            ],
            result.evaluatedExperimentsReportingData
        )
    }

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

        self.deviceInfo.stableContactID = "active-contact-id"

        self.remoteData.payloads = [createPayload([
            experiment1.toString,
            experiment2.toString
        ])]

        self.audienceChecker.onEvaluate = { audience, newUserEvaluationDate, _ in
            return audience == audienceSelector2
        }

        let result = try await subject.evaluateExperiments(
            info: MessageInfo.empty,
            deviceInfoProvider: self.deviceInfo
        )!

        XCTAssertTrue(result.isMatch)
        XCTAssertEqual("active-contact-id", result.contactID)
        XCTAssertEqual("channel-id", result.channelID)

        XCTAssertEqual(
            [
                experiment1.reportingMetadata,
                experiment2.reportingMetadata
            ],
            result.evaluatedExperimentsReportingData
        )
    }

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

        self.deviceInfo.stableContactID = "active-contact-id"

        self.remoteData.payloads = [createPayload([
            experiment1.toString,
            experiment2.toString
        ])]

        self.audienceChecker.onEvaluate = { audience, newUserEvaluationDate, _ in
            return audience == audienceSelector2
        }

        let result = try await subject.evaluateExperiments(
            info: MessageInfo.empty,
            deviceInfoProvider: self.deviceInfo
        )!

        XCTAssertTrue(result.isMatch)
        XCTAssertEqual("active-contact-id", result.contactID)
        XCTAssertEqual("channel-id", result.channelID)

        XCTAssertEqual(
            [
                experiment2.reportingMetadata
            ],
            result.evaluatedExperimentsReportingData
        )
    }

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
            return true
        }

        let result = try await subject.evaluateExperiments(
            info: MessageInfo(
                messageType: "commercial",
                campaigns: try! AirshipJSON.wrap(["categories": ["foo", "bar"]])
            ),
            deviceInfoProvider: self.deviceInfo
        )!

        XCTAssertTrue(result.isMatch)
        XCTAssertEqual([experiment.reportingMetadata], result.evaluatedExperimentsReportingData)

        var emptyResult = try await subject.evaluateExperiments(
            info: MessageInfo(messageType: "transactional"),
            deviceInfoProvider: self.deviceInfo
        )

        XCTAssertNil(emptyResult)

        emptyResult = try await subject.evaluateExperiments(
            info: MessageInfo(
                messageType: "commercial",
                campaigns: try! AirshipJSON.wrap(["categories": ["foo", "bar", "transactional campaign"]])
            ),
            deviceInfoProvider: self.deviceInfo
        )

        XCTAssertNil(emptyResult)
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
    static let empty = MessageInfo(messageType: "", campaigns: nil)
}

fileprivate extension Experiment {
    var toString: String {
        let encoder = JSONEncoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        encoder.dateEncodingStrategy = .formatted(formatter)

        return try! AirshipJSON.wrap(self).toString(encoder: encoder)
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
