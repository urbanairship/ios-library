
import XCTest

@testable
import AirshipCore

final class ChannelAPIClientTest: XCTestCase {
    private var config: RuntimeConfig = .testConfig()
    private let session = TestAirshipRequestSession()
    private var client: ChannelAPIClient!
    private let encoder = JSONEncoder()

    override func setUpWithError() throws {
        self.client = ChannelAPIClient(
            config: self.config,
            session: self.session
        )
    }

    func testCreate() async throws {
        let payload = ChannelRegistrationPayload()

        self.session.data = try AirshipJSONUtils.data([
            "channel_id": "some-channel-id"
        ])

        self.session.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: [String: String]()
        )

        let response = try await self.client.createChannel(payload: payload)
        XCTAssertEqual("some-channel-id", response.result!.channelID)
        XCTAssertEqual(
            "https://device-api.urbanairship.com/api/channels/some-channel-id",
            response.result!.location.absoluteString
        )

        let request = self.session.lastRequest!
        XCTAssertEqual("POST", request.method)
        XCTAssertEqual(AirshipRequestAuth.generatedAppToken, request.auth)
        XCTAssertEqual("https://device-api.urbanairship.com/api/channels/", request.url?.absoluteString)
        XCTAssertEqual(try! AirshipJSON.wrap(payload), try! AirshipJSON.from(data: request.body))
    }

    func testCreateInvalidResponse() async throws {
        let payload = ChannelRegistrationPayload()

        self.session.data = try AirshipJSONUtils.data([
            "not-right": "some-channel-id"
        ])

        self.session.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: [String: String]()
        )

        do {
            _ = try await self.client.createChannel(payload: payload)
            XCTFail("Should throw")
        } catch {}
    }

    func testCreateError() async throws {
        let payload = ChannelRegistrationPayload()
        self.session.error = AirshipErrors.error("Error!")
        do {
            _ = try await self.client.createChannel(payload: payload)
            XCTFail("Should throw")
        } catch {}
    }

    func testCreateFailed() async throws {
        let payload = ChannelRegistrationPayload()
        self.session.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 400,
            httpVersion: "",
            headerFields: [String: String]()
        )

        let response = try await self.client.createChannel(payload: payload)
        XCTAssertEqual(400, response.statusCode)
    }

    func testUpdate() async throws {
        let payload = ChannelRegistrationPayload()

        self.session.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: [String: String]()
        )

        let response = try await self.client.updateChannel(
            "some-channel-id",
            payload: payload
        )

        XCTAssertEqual("some-channel-id", response.result!.channelID)
        XCTAssertEqual(
            "https://device-api.urbanairship.com/api/channels/some-channel-id",
            response.result!.location.absoluteString
        )

        let request = self.session.lastRequest!
        XCTAssertEqual("PUT", request.method)

        XCTAssertEqual(AirshipRequestAuth.channelAuthToken(identifier: "some-channel-id"), request.auth)
        XCTAssertEqual(try! AirshipJSON.wrap(payload), try! AirshipJSON.from(data: request.body))
        XCTAssertEqual("https://device-api.urbanairship.com/api/channels/some-channel-id", request.url?.absoluteString)

    }
    func testUpdateError() async throws {
        let payload = ChannelRegistrationPayload()
        self.session.error = AirshipErrors.error("Error!")
        do {
            _ = try await self.client.updateChannel(
                "some-channel-id",
                payload: payload
            )
            XCTFail("Should throw")
        } catch {}
    }

    func testUpdateFailed() async throws {
        let payload = ChannelRegistrationPayload()
        self.session.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 400,
            httpVersion: "",
            headerFields: [String: String]()
        )

        let response = try await self.client.updateChannel(
            "some-channel-id",
            payload: payload
        )
        XCTAssertEqual(400, response.statusCode)
    }

}
