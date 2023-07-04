/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class ExperimentManagerTest: XCTestCase {
    
    private var channelID: String? = "channel-id"
    private var contactID: String = "some-contact-id"
    
    private let remoteData: MockRemoteDataProvider = MockRemoteDataProvider()
    private var subject: ExperimentManager!
    private let audienceChecker: TestAudienceChecker = TestAudienceChecker()

    override func setUpWithError() throws {
        self.subject = ExperimentManager(
            dataStore: PreferenceDataStore(appKey: UUID().uuidString),
            remoteData: remoteData,
            channelIDProvider: {
                return self.channelID
            },
            stableContactIDProvider: {
                return self.contactID
            },
            audienceChecker: audienceChecker
        )
    }

    func testManagerParseValidExperimentData() async throws {
        let experimentId = "fake-id"
        self.remoteData.payloads = [createPayload([generateExperiment(id: experimentId)])]
        guard let experiment = await self.subject.getExperiment(id: experimentId) else {
            XCTFail("Experiment not found")
            return
        }
        
        let reportingMetadata = [
            "experiment_id": "\(experimentId)"
        ]
        
        XCTAssertNotNil(experiment)
        XCTAssertEqual(experimentId, experiment.id)
        XCTAssertEqual("farm_hash", experiment.audienceSelector.hashSelector!.hash.algorithm.rawValue)
        XCTAssertEqual("contact", experiment.audienceSelector.hashSelector!.hash.property.rawValue)
        XCTAssertEqual(Date(timeIntervalSince1970: 1684868854), experiment.lastUpdated)
        XCTAssertEqual("Holdout", experiment.type.rawValue)
        XCTAssertEqual("Static", experiment.resolutionType.rawValue)
        XCTAssertEqual(reportingMetadata, experiment.reportingMetadata.unWrap())
    }
    
    func testExperimentManagerOmitsInvalidExperiments() async {
        let valid = generateExperiment(id: "valid-experiment", hashIdentifier: "channel")
        let invalid = generateExperiment(id: "invalid-experiment", hashIdentifier: "invalid")
        
        self.remoteData.payloads = [createPayload([valid, invalid])]

        let validExperiment = await self.subject.getExperiment(id: "valid-experiment")
        XCTAssertNotNil(validExperiment)
        XCTAssertEqual("valid-experiment", validExperiment?.id)
        XCTAssertEqual("channel", validExperiment!.audienceSelector.hashSelector!.hash.property.rawValue)

        let invalidExperiment = await self.subject.getExperiment(id: "invalid-experiment")
        XCTAssertNil(invalidExperiment)
    }

    func testExperimentManagerParseMultipleExperiments() async {
        let experiment1 = generateExperiment(id: "id1")
        let experiment2 = generateExperiment(id: "id2")
        self.remoteData.payloads = [createPayload([experiment1]), createPayload([experiment2])]

        let ex1 = await self.subject.getExperiment(id: "id1")
        XCTAssertNotNil(ex1)

        let ex2 = await self.subject.getExperiment(id: "id2")
        XCTAssertNotNil(ex2)
    }

    func testExperimentManagerHandleNoExperimentsPayload() async {
        self.remoteData.payloads = [createPayload(["{}"])]

        let experiment = await self.subject.getExperiment(id: "id")
        XCTAssertNil(experiment)
    }

    func testExperimentManagerHandleInvalidPayload() async {
        let experiment = "{\"invalid\": \"experiment\"}"
        self.remoteData.payloads = [createPayload([experiment])]

        let result = await subject.getExperiment(id: "id")
        XCTAssertNil(result)
    }

    func testResultNoExperiments() async throws {
        self.remoteData.payloads = [createPayload([])]

        let result = try await subject.evaluateExperiments(
            info: MessageInfo.empty,
            contactID: nil
        )


        XCTAssertFalse(result.isMatch)
        XCTAssertEqual(contactID, result.contactID)
        XCTAssertEqual(channelID, result.channelID)
        XCTAssertEqual([], result.evaluatedExperimentsReportingData)
    }

    func testResultNoMatch() async throws {
        let json = generateExperiment(id: "fake-id", hashIdentifier: "channel")
        self.remoteData.payloads = [createPayload([json])]

        let result = try await subject.evaluateExperiments(
            info: MessageInfo.empty,
            contactID: nil
        )


        XCTAssertFalse(result.isMatch)
        XCTAssertEqual(contactID, result.contactID)
        XCTAssertEqual(channelID, result.channelID)

        XCTAssertEqual(
            [
                try! AirshipJSON.wrap(["experiment_id": "fake-id"])
            ],
            result.evaluatedExperimentsReportingData
        )
    }

    func testResultMatch() async throws {
        let activeContactID = "active-contact-id"

        self.remoteData.payloads = [createPayload([
            generateExperiment(id: "unmatched", bucketMax: 1239),
            generateExperiment(id: "matched", bucketMin: 1239)
        ])]

        self.audienceChecker.onEvaluate = { audience, newUserEvaluationDate, contactID in
            XCTAssertEqual(contactID, activeContactID)
            // match only the `matched` experiement
            return audience.hashSelector?.bucket.min == 1239
        }

        let result = try await subject.evaluateExperiments(
            info: MessageInfo.empty,
            contactID: activeContactID
        )

        XCTAssertTrue(result.isMatch)
        XCTAssertEqual(activeContactID, result.contactID)
        XCTAssertEqual(channelID, result.channelID)

        XCTAssertEqual(
            [
                try! AirshipJSON.wrap(["experiment_id": "unmatched"]),
                try! AirshipJSON.wrap(["experiment_id": "matched"])
            ],
            result.evaluatedExperimentsReportingData
        )
    }

    private func generateExperiment(
        id: String,
        hashIdentifier: String = "contact",
        hashAlgorithm: String = "farm_hash",
        hashOverrides: String? = nil,
        bucketMin: Int = 0,
        bucketMax: Int = 16384,
        messageTypeToExclude: String = "Transactional"
    ) -> String {
        
        let overrides: String
        if let value = hashOverrides {
            overrides = ",\"hash_identifier_overrides\": \(value)"
        } else {
            overrides = ""
        }
        
        return """
        {
            "id": "\(id)",
            "experimentType": "Holdout",
            "created": "2023-05-23T19:07:34Z",
            "last_updated": "2023-05-23T19:07:34Z",
            "reporting_metadata": {
                "experiment_id": "\(id)"
            },
            "type": "Static",
            "audience_selector": {
                "hash": {
                    "audience_hash": {
                        "hash_prefix": "e66a2371-fecf-41de-9238-cb6c28a86cec:",
                        "num_hash_buckets": 16384,
                        "hash_identifier": "\(hashIdentifier)",
                        "hash_algorithm": "\(hashAlgorithm)"
                        \(overrides)
                    },
                    "audience_subset": {
                        "min_hash_bucket": \(bucketMin),
                        "max_hash_bucket": \(bucketMax)
                    }
                }
            },
            "message_exclusions": [
                {
                    "message_type": {
                        "value": {
                            "equals": "\(messageTypeToExclude)"
                        }
                    }
                }
            ]
        }
        """
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
    static let empty = MessageInfo(messageType: "")
}

private final class TestAudienceChecker: DeviceAudienceChecker, @unchecked Sendable {

    var onEvaluate: ((DeviceAudienceSelector, Date, String?) async throws -> Bool)!

    func evaluate(
        audience: DeviceAudienceSelector,
        newUserEvaluationDate: Date,
        contactID: String?
    ) async throws -> Bool {
        return try await self.onEvaluate?(audience, newUserEvaluationDate, contactID) ?? false
    }
}
